import 'dart:async';

import 'package:better_player/better_player.dart' as bp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../data/models/video_model.dart';

/// Backend abstraction over the two video engines the app can run on.
///
/// better_player wraps ExoPlayer, which is what makes 1080p+ DASH, quality
/// switching and Picture-in-Picture possible. It is Android/iOS only, though,
/// and this project also builds for Linux and Windows, so every platform that
/// cannot load the plugin keeps using plain `video_player` behind the same
/// interface instead of losing video playback entirely.
/// One quality rung the engine can be asked for.
///
/// DASH rungs are not URLs, so they cannot be modelled as [VideoResolution]:
/// ExoPlayer picks them by track token and the ladder lives in the manifest,
/// not in the API payload. The engine owns the list, which is why this type is
/// declared here rather than in the model layer.
class PlaybackQuality {
  final String label;
  final int? height;

  /// "Auto" hands the ladder back to the engine's own adaptive selection.
  final bool isAuto;

  /// Progressive rungs switch by re-opening the source URL.
  final VideoResolution? resolution;

  /// DASH rungs switch by track token.
  final Object? track;

  const PlaybackQuality({
    required this.label,
    this.height,
    this.isAuto = false,
    this.resolution,
    this.track,
  });
}

abstract class VideoPlaybackBackend {
  bool get isReady;
  bool get isPlaying;
  bool get isBuffering;
  bool get supportsPictureInPicture;

  /// Rungs the engine can be switched to, best first. Empty when the source has
  /// no ladder to switch between.
  List<PlaybackQuality> get qualities;

  /// True when the source is a manifest the engine reads tracks from.
  ///
  /// Tracks from a manifest cannot be swapped in place: a representation is one
  /// whole file with no segment index, so the extractor has to read from byte
  /// zero to reach the playhead. Switching at 8:30 leaves it scanning hundreds
  /// of megabytes and playback never resumes, so the controller reopens the
  /// source instead.
  bool get usesManifest;

  /// True when a quality change is just a track switch, so the source can stay
  /// open.
  ///
  /// HLS qualifies: every rung is its own playlist, so ExoPlayer swaps tracks
  /// and keeps the position. DASH does not — each rung is a whole file, so the
  /// only way to change one is to reopen the manifest.
  bool get switchesQualityInPlace;

  /// The rung in force, or null while the engine is choosing on its own.
  PlaybackQuality? get activeQuality;

  /// True once the engine has a picture. A DASH track whose every rung the
  /// device cannot decode fails silently: audio keeps playing, no frame is
  /// ever produced, and no error is raised.
  bool get hasVideoFrame;

  Duration get position;
  Duration get duration;
  double get aspectRatio;
  String? get error;

  Widget buildSurface(GlobalKey surfaceKey);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> applyQuality(PlaybackQuality quality);
  Future<void> dispose();
}

/// Video playback, owned by the app-wide video session.
///
/// Deliberately separate from `PlayerController`, which owns the audio path
/// (just_audio + audio_service) and the queue. Two players never run at once:
/// the session pauses audio before a video starts, and pauses the video when
/// audio takes over. It outlives the Watch page, so leaving the page for the
/// mini player and coming back never re-buffers the stream.
class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController({
    required this.repository,
    this.onPictureInPicture,
  });

  final Object repository;

  /// Enters Picture-in-Picture for the whole activity. The plugin's own PiP is
  /// not used: on Android it pushes a fullscreen route of its own, which fights
  /// the router and the activity-level PiP the music player already uses.
  Future<void> Function()? onPictureInPicture;

  VideoPlaybackBackend? _backend;
  Timer? _poll;

  bool _isLoading = false;
  bool _isReady = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _error;
  double _speed = 1;
  int _generation = 0;

  /// Playhead second the listeners were last told about, so a poll that changed
  /// nothing does not rebuild the overlay.
  int _lastSyncedSecond = -1;

  /// Video currently open, so a rung change can reopen it.
  String _videoId = '';

  /// Rungs the API offered for the open video, straight from `/stream`.
  ///
  /// A filtered manifest only describes the one rung it was asked for, so the
  /// menu can no longer come from the engine: the full ladder has to be kept
  /// from the resolve that opened the video.
  List<VideoResolution> _ladder = const [];

  /// Height the open manifest was narrowed to, null for progressive sources.
  int? _requestedHeight;

  /// Rung "Auto" stands for: the highest AVC rung up to [_autoCeiling].
  int? _autoHeight;

  /// Whether the rung in force was reached through "Auto".
  bool _isAuto = false;

  /// Ceiling for "Auto": the highest rung a device can be trusted to decode.
  ///
  /// YouTube only ships 4K as AV1/VP9 while 1080p and below stay AVC, and the
  /// rungs a device cannot decode play as audio with a black rectangle.
  static const int _autoCeiling = 1080;

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get supportsPictureInPicture =>
      onPictureInPicture != null &&
      (_backend?.supportsPictureInPicture ?? false);

  /// Video currently open, empty when nothing is.
  String get videoId => _videoId;

  /// The one place that decides whether a spinner is on screen. Resolving the
  /// stream, the engine opening it and mid-playback buffering are all the same
  /// wait to the user, so they share a single indicator.
  bool get showsSpinner {
    if (_error != null) return false;
    if (_isLoading || _isBuffering) return true;
    final backend = _backend;
    return backend != null && !backend.isReady;
  }

  Duration get position => _backend?.position ?? Duration.zero;
  Duration get duration => _backend?.duration ?? Duration.zero;
  double get aspectRatio {
    final ar = _backend?.aspectRatio ?? 0;
    return ar > 0 ? ar : 16 / 9;
  }

  String? get error => _error;
  double get speed => _speed;

  /// Rungs the menu offers.
  ///
  /// A manifest is served one rung at a time, so its representations only ever
  /// describe what is already playing; the ladder `/stream` returned is the real
  /// menu. A progressive source has no manifest to reopen, so the engine's own
  /// list is used.
  List<PlaybackQuality> get qualities {
    final backend = _backend;
    if (backend == null) return const [];
    if (!backend.usesManifest || _ladder.isEmpty) return backend.qualities;
    return [
      PlaybackQuality(
        label: 'Auto',
        height: _autoHeight,
        isAuto: true,
      ),
      ..._ladder.map(
        (r) => PlaybackQuality(label: r.label, height: r.height),
      ),
    ];
  }

  /// Label of the rung in force, or null before anything is playing.
  ///
  /// A filtered manifest names exactly the rung that was asked for, so this can
  /// report it directly: the label is what is really decoding, not a guess.
  String? get activeQuality {
    final backend = _backend;
    if (backend == null) return null;
    final height = _requestedHeight;
    if (!backend.usesManifest || height == null) {
      return backend.activeQuality?.label;
    }
    return _isAuto ? 'Auto' : '${height}p';
  }

  /// False while ExoPlayer is playing audio with no picture on screen.
  bool get hasVideoFrame => _backend?.hasVideoFrame ?? false;

  /// The picture, or a black frame until there is one. The waiting indicator is
  /// drawn by the overlay ([showsSpinner]), never here, so it appears once.
  Widget buildSurface(GlobalKey surfaceKey) {
    final backend = _backend;
    if (backend == null || !backend.isReady) {
      return const ColoredBox(color: Colors.black);
    }
    return backend.buildSurface(surfaceKey);
  }

  /// Resolves the stream and starts playback at [start].
  ///
  /// [pin] asks for one rung of the ladder. A DASH manifest is served with that
  /// single rung in it, because every rendition is a whole file: ExoPlayer
  /// switching between them re-reads the asset from byte zero, which on a long
  /// video stalls long enough to look like a hang, and its own first pick is the
  /// lowest rung because the bandwidth estimate starts at 200 kbps. So the rung
  /// is decided here instead of left to the engine.
  ///
  /// HLS wins over DASH whenever the API offers it. There the ladder is read
  /// from the master playlist by the engine, so nothing is pinned and no reload
  /// is needed to change quality — and seeking works, which is the whole point:
  /// each rendition is a playlist of short segments rather than one multi-GB
  /// asset with no index.
  ///
  /// Safe to call again for a different video: the previous engine is disposed
  /// and a stale in-flight resolve is dropped through [_generation].
  Future<void> load(
    String videoId, {
    PlaybackQuality? pin,
    Duration start = Duration.zero,
  }) async {
    final gen = ++_generation;
    _videoId = videoId;
    _isLoading = true;
    _isBuffering = false;
    _isPlaying = false;
    _error = null;
    _isReady = false;
    _lastSyncedSecond = -1;
    _notify();

    await _teardownBackend();
    if (gen != _generation) return;

    try {
      final info = await (repository as dynamic)
          .getStreamInfo(videoId, format: 'video') as StreamInfo;
      if (gen != _generation) return;

      final hls = info.hlsUrl;
      final isHls = hls != null && hls.isNotEmpty;
      final url = isHls ? hls : info.videoUrl;
      if (url == null || url.isEmpty) {
        _fail('Vídeo indisponível para este formato');
        return;
      }

      _ladder = isHls
          ? (info.videoResolutions.isEmpty ? const [] : info.videoResolutions)
          : info.videoResolutions;
      _autoHeight = _autoRung(_ladder);
      _isAuto = pin == null || pin.isAuto;
      final isDash = !isHls && info.videoFormat == 'dash';
      // Progressive sources switch in place and never carry the query. A DASH
      // manifest gets the rung baked in; HLS keeps every variant and lets the
      // engine pick, so there is nothing to pin.
      _requestedHeight = isDash ? (pin?.height ?? _autoHeight) : null;

      _backend = buildBackend(
        url: _rungUrl(url, _requestedHeight),
        format: isHls ? 'hls' : info.videoFormat,
        resolutions: info.switchableResolutions,
        headers: const {'User-Agent': _defaultUserAgent},
        startPosition: start,
      );

      _isReady = _backend!.isReady;
      _isPlaying = _backend!.isPlaying;
      _isLoading = false;
      _poll?.cancel();
      _poll = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _syncFromBackend(),
      );
      _notify();

      await _backend!.play();
      _settleTrack(gen);
    } catch (e) {
      if (gen != _generation) return;
      _fail('Não foi possível carregar o vídeo: $e');
    }
  }

  /// Rescues a player that is running but showing no picture.
  ///
  /// A DASH track whose every rendition the device cannot decode fails without
  /// an error: ExoPlayer reports ready and keeps playing audio, so the user sees
  /// a black rectangle. Giving the engine a few seconds to settle and then
  /// dropping it onto the safest rung turns that silent failure into playback.
  Future<void> _settleTrack(int gen) async {
    final backend = _backend;
    if (backend == null) return;
    // A manifest already holds a single rung, so there is nothing to settle
    // unless the user asked for one above what the device can decode: that case
    // shows as audio with a black rectangle, and the fix is a different manifest.
    final current = _requestedHeight;
    if (!backend.usesManifest) return;
    if (current == null || current == _autoHeight) return;

    const tick = Duration(milliseconds: 500);
    // Decoder setup takes a while on a cold start, so an early poll catches a
    // player that has not tried anything yet. Only a picture-free player that is
    // already playing audio counts as a failure.
    const settle = 12;
    for (var i = 0; i < 24; i++) {
      await Future<void>.delayed(tick);
      if (gen != _generation) return;
      if (backend.error != null) return;
      if (backend.hasVideoFrame) return;
      if (i < settle || !backend.isPlaying) continue;
      await setQuality(
        const PlaybackQuality(label: 'Auto', isAuto: true),
      );
      return;
    }
  }


  Future<void> togglePlayPause() async {
    final backend = _backend;
    if (backend == null) return;
    if (backend.isPlaying) {
      await backend.pause();
    } else {
      await backend.play();
    }
    _syncFromBackend();
  }

  Future<void> play() async {
    await _backend?.play();
    _syncFromBackend();
  }

  Future<void> pause() async {
    await _backend?.pause();
    _syncFromBackend();
  }

  /// Re-opens the current video after a failure, from where it stopped.
  Future<void> retry() async {
    if (_videoId.isEmpty) return;
    await load(_videoId, start: position);
  }

  Future<void> seek(Duration to) async {
    await _backend?.seek(to);
    _syncFromBackend();
  }

  Future<void> seekBy(Duration delta) async {
    final backend = _backend;
    if (backend == null) return;
    final target = backend.position + delta;
    final dur = backend.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    await backend.seek(clamped);
    _syncFromBackend();
  }

  Future<void> cycleSpeed() async {
    const steps = [1.0, 1.25, 1.5, 1.75, 2.0, 0.5, 0.75];
    final next = steps[(steps.indexOf(_speed) + 1) % steps.length];
    await _backend?.setPlaybackSpeed(next);
    _speed = next;
    _notify();
  }

  /// Asks the API for one rung. A progressive URL is returned untouched.
  String _rungUrl(String url, int? height) {
    if (height == null) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}height=$height';
  }

  /// Rung "Auto" resolves to: the highest AVC rung up to [_autoCeiling].
  ///
  /// Falls back to the smallest rung on the ladder, which is AVC in practice and
  /// decodes anywhere, so Auto never lands on something unplayable.
  int? _autoRung(List<VideoResolution> ladder) {
    if (ladder.isEmpty) return null;
    int? best;
    for (final r in ladder) {
      final h = r.height ?? 0;
      if (h <= 0 || h > _autoCeiling) continue;
      if (!(r.vcodec ?? '').toLowerCase().startsWith('avc')) continue;
      if (best == null || h > best) best = h;
    }
    if (best != null) return best;
    final heights = ladder.map((r) => r.height ?? 0).where((h) => h > 0);
    return heights.isEmpty ? null : heights.reduce((a, b) => a < b ? a : b);
  }

  /// Switches to [quality].
  ///
  /// A manifest source is reopened rather than retargeted when the source
  /// cannot switch in place: a DASH rendition is one whole file, so there is no
  /// index to seek inside and swapping tracks at a playhead in the middle of the
  /// video leaves the extractor reading from byte zero. Reopening costs a
  /// restart, which is the price of being able to choose a rung at all.
  /// Progressive sources switch in place as before, and HLS does too — its
  /// rungs are separate playlists, so the engine just swaps tracks and the
  /// position survives.
  Future<void> setQuality(PlaybackQuality quality) async {
    final backend = _backend;
    if (backend == null) return;

    if (backend.usesManifest && !backend.switchesQualityInPlace) {
      final target = quality.isAuto ? _autoHeight : quality.height;
      if (target == null || target == _requestedHeight) return;
      // Reopening costs a restart and a re-download of the audio track; it is
      // the price of the rung actually taking effect. The playhead survives, so
      // the switch reads as a quality change instead of a new video.
      await load(_videoId, pin: quality, start: position);
      return;
    }

    await backend.applyQuality(quality);
    _syncFromBackend();
  }

  Future<void> enterPictureInPicture() async {
    if (!supportsPictureInPicture) return;
    await onPictureInPicture?.call();
  }

  Future<void> stop() async {
    _generation++;
    _videoId = '';
    _error = null;
    _isLoading = false;
    _isReady = false;
    _isPlaying = false;
    _isBuffering = false;
    await _teardownBackend();
    _notify();
  }

  void _syncFromBackend() {
    final backend = _backend;
    if (backend == null) return;
    _handleBackendError();
    final ready = backend.isReady;
    final playing = backend.isPlaying;
    final buffering = backend.isBuffering;
    // The elapsed label is rendered from `position` at build time, so a poll
    // that only fires on state changes leaves the clock frozen at whatever the
    // last buffering blip happened to be. A whole second of movement is enough
    // to make the label tick without rebuilding the overlay 30 times a second.
    final second = backend.position.inSeconds;
    if (ready == _isReady &&
        playing == _isPlaying &&
        buffering == _isBuffering &&
        second == _lastSyncedSecond) {
      return;
    }
    _lastSyncedSecond = second;
    _isReady = ready;
    _isPlaying = playing;
    _isBuffering = buffering;
    _notify();
  }

  void _handleBackendError() {
    final err = _backend?.error;
    if (err != null && err != _error) {
      _error = err;
      _isLoading = false;
      _isReady = false;
      _notify();
    }
  }

  void _fail(String message) {
    _error = message;
    _isLoading = false;
    _isReady = false;
    _isPlaying = false;
    _notify();
  }

  void _notify() {
    if (!hasListeners || _disposed) return;
    notifyListeners();
  }

  bool _disposed = false;

  /// Drops the engine only after the surfaces stopped drawing it.
  ///
  /// A surface keeps the engine's widget mounted until it rebuilds, so
  /// disposing first leaves a live BetterPlayer on a dead controller — the
  /// "used after being disposed" errors on every reload. Unmounting goes first,
  /// with a timeout because no frame is produced while the app is in the
  /// background.
  Future<void> _teardownBackend() async {
    _poll?.cancel();
    _poll = null;
    final backend = _backend;
    if (backend == null) return;
    _backend = null;
    _notify();
    await WidgetsBinding.instance.endOfFrame
        .timeout(const Duration(milliseconds: 300), onTimeout: () {});
    await backend.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _poll?.cancel();
    _poll = null;
    _backend?.dispose();
    _backend = null;
    super.dispose();
  }
}

/// Picks the engine. ExoPlayer where the plugin exists, video_player elsewhere.
VideoPlaybackBackend buildBackend({
  required String url,
  required String? format,
  required List<VideoResolution> resolutions,
  required Map<String, String> headers,
  required Duration startPosition,
}) {
  // better_player 1.18 ships Android, iOS and web implementations only. Windows
  // has no plugin implementation, so it has to fall back with the rest.
  final useBetterPlayer = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (useBetterPlayer) {
    return BetterPlayerBackend(
      url: url,
      format: format,
      resolutions: resolutions,
      headers: headers,
      startPosition: startPosition,
    );
  }
  return VideoPlayerBackend(
    url: url,
    format: format,
    startPosition: startPosition,
  );
}

/// Player headers ExoPlayer needs to get a byte range out of the CDN; without
/// them googlevideo answers 403 to the manifest fetch.
const _defaultUserAgent =
    'com.google.android.youtube/19.29.37 (Linux; U; Android 14) gzip';

/// ExoPlayer backend. DASH-aware, so it is the only engine that can reach the
/// top of the quality ladder.
class BetterPlayerBackend implements VideoPlaybackBackend {
  BetterPlayerBackend({
    required String url,
    required String? format,
    required List<VideoResolution> resolutions,
    required Map<String, String> headers,
    required Duration startPosition,
  }) {
    // A manifest source (DASH or HLS) has its ladder read by the engine, so
    // the URL map only applies to progressive sources.
    _isAdaptive = format == 'dash' || format == 'hls';
    _isHls = format == 'hls';
    _progressiveRungs = _isAdaptive ? const [] : resolutions;
    final qualityMap = <String, String>{
      for (final r in resolutions) r.label: r.url,
    };
    _controller = bp.BetterPlayerController(
      bp.PlayerConfiguration(
        // The app draws its own YouTube-style controls; the plugin's overlay
        // would sit on top of them and fight for the same taps.
        controlsConfiguration: const bp.PlayerControlsConfiguration(
          showControls: false,
          showControlsOnInitialize: false,
        ),
        // The page, the fullscreen route and the mini player each mount their
        // own BetterPlayer on this one controller. With autoDispose on, the
        // first of them to unmount kills the controller under the others.
        autoDispose: false,
        // Visibility- and lifecycle-driven pauses belong to the video session:
        // the plugin pauses whenever its widget is covered, which is exactly
        // what happens when the Watch page hands over to the mini player.
        handleLifecycle: false,
        fit: BoxFit.contain,
        // Applied once the source is initialized; a seek issued before that
        // throws inside the plugin.
        startAt: startPosition > Duration.zero ? startPosition : null,
      ),
      betterPlayerDataSource: bp.PlayerDataSource(
          bp.DataSourceType.network,
          url,
          headers: headers,
          resolutions: _isAdaptive || qualityMap.isEmpty ? null : qualityMap,
          videoFormat: _videoFormatFor(format),
          videoExtension: format == 'dash' ? 'mpd' : null,
        ),
    );
    // The engine reports position and error through this listener, which is the
    // only per-frame notification channel in the 1.x API.
    _controller!.addVideoListener(_onEngineUpdate);
  }

  bp.BetterPlayerController? _controller;
  String? _error;

  static bp.VideoFormat? _videoFormatFor(String? format) {
    switch (format) {
      case 'dash':
        return bp.VideoFormat.dash;
      case 'hls':
        return bp.VideoFormat.hls;
      default:
        return bp.VideoFormat.other;
    }
  }

  void _onEngineUpdate() {
    final err = _controller?.videoPlayerValue?.errorDescription;
    if (err != null) _error = err;
  }

  @override
  bool get isReady => _controller?.isInitialized ?? false;

  @override
  bool get isPlaying => _controller?.isPlaying() ?? false;

  @override
  bool get isBuffering => _controller?.isBuffering() ?? false;

  /// PiP is the activity-level one in MainActivity, which only exists on
  /// Android.
  @override
  bool get supportsPictureInPicture =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get usesManifest => _isAdaptive;

  @override
  bool get switchesQualityInPlace => _isAdaptive && _isHls;

  /// Rungs come from the parsed manifest, so the list only exists once the
  /// engine has read it. A progressive source instead exposes the API's ladder,
  /// which is a list of plain URLs.
  @override
  List<PlaybackQuality> get qualities {
    final c = _controller;
    if (c == null || !isReady) return const [];
    if (_isAdaptive) {
      final tracks = c.betterPlayerAsmsTracks;
      if (tracks.isEmpty) return const [];
      final rungs = tracks
          .where((t) => (t.height ?? 0) > 0)
          .map((t) => PlaybackQuality(
                label: '${t.height}p',
                height: t.height,
                track: t,
              ))
          .toList()
        ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
      return [
        const PlaybackQuality(label: 'Auto', isAuto: true),
        ...rungs,
      ];
    }
    return _progressiveRungs
        .map((r) => PlaybackQuality(
              label: r.label,
              height: r.height,
              resolution: r,
            ))
        .toList();
  }

  @override
  PlaybackQuality? get activeQuality {
    final c = _controller;
    if (c == null) return null;
    if (_isAdaptive) {
      final t = c.betterPlayerAsmsTrack;
      // Null means Auto: the engine is choosing, and there is nothing to mark.
      if (t == null || (t.height ?? 0) == 0) return null;
      return PlaybackQuality(label: '${t.height}p', height: t.height, track: t);
    }
    return _activeResolution == null
        ? null
        : PlaybackQuality(
            label: _activeResolution!.label,
            height: _activeResolution!.height,
            resolution: _activeResolution,
          );
  }

  /// True once ExoPlayer has produced a frame. The reported size is the only
  /// signal that separates "playing" from "playing audio with no picture".
  @override
  bool get hasVideoFrame => _controller?.videoPlayerValue?.size != null;

  bool _isAdaptive = false;
  bool _isHls = false;
  List<VideoResolution> _progressiveRungs = const [];
  VideoResolution? _activeResolution;

  @override
  Duration get position => _controller?.videoPlayerValue?.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.duration ?? Duration.zero;

  @override
  double get aspectRatio {
    final ar = _controller?.getAspectRatio();
    return (ar != null && ar > 0) ? ar : 16 / 9;
  }

  @override
  String? get error => _error;

  @override
  Widget buildSurface(GlobalKey surfaceKey) =>
      bp.BetterPlayer(key: surfaceKey, controller: _controller!);

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(Duration position) async => _controller?.seekTo(position);

  @override
  Future<void> setPlaybackSpeed(double speed) async => _controller?.setSpeed(speed);

  @override
  Future<void> applyQuality(PlaybackQuality quality) async {
    if (quality.isAuto) {
      _controller?.setTrack(bp.PlayerAsmsTrack.defaultTrack());
      _activeResolution = null;
      return;
    }
    final track = quality.track;
    if (track is bp.PlayerAsmsTrack) {
      // The plugin throws when the data source has not finished initializing.
      // The controller re-applies the pin on its next tick, so a miss here is
      // not a failure and must not abort the loop that is driving the retry.
      try {
        _controller?.setTrack(track);
      } catch (_) {
        return;
      }
      return;
    }
    final resolution = quality.resolution;
    if (resolution == null) return;
    // ExoPlayer re-opens the source for a new URL and keeps the position, so a
    // rung swap costs a re-buffer but never a restart.
    await _controller?.setResolution(resolution.url);
    _activeResolution = resolution;
  }

  @override
  Future<void> dispose() async {
    _controller?.removeVideoListener(_onEngineUpdate);
    // forceDispose: the plugin skips disposal when autoDispose is off, and a
    // leaked ExoPlayer holds a wake lock and a decoder for the whole session.
    _controller?.dispose(forceDispose: true);
    _controller = null;
  }
}

/// video_player backend, used where the better_player plugin is unavailable.
class VideoPlayerBackend implements VideoPlaybackBackend {
  VideoPlayerBackend({
    required String url,
    required String? format,
    required Duration startPosition,
  }) {
    _controller = vp.VideoPlayerController.networkUrl(
      Uri.parse(url),
      // The manifests carry no .mpd/.m3u8 suffix, so the hint is what tells the
      // platform which demuxer to use.
      formatHint: switch (format) {
        'hls' => vp.VideoFormat.hls,
        'dash' => vp.VideoFormat.dash,
        _ => null,
      },
      httpHeaders: const {'User-Agent': _defaultUserAgent},
    );
    _initialize(startPosition);
  }

  vp.VideoPlayerController? _controller;
  bool _ready = false;

  Future<void> _initialize(Duration startPosition) async {
    try {
      await _controller?.initialize();
      if (startPosition > Duration.zero) {
        await _controller?.seekTo(startPosition);
      }
      _ready = true;
    } catch (_) {}
  }

  @override
  bool get isReady => _ready;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  bool get isBuffering => _controller?.value.isBuffering ?? false;

  @override
  bool get supportsPictureInPicture => false;

  @override
  bool get usesManifest => false;

  @override
  bool get switchesQualityInPlace => true;

  @override
  List<PlaybackQuality> get qualities => const [];

  @override
  PlaybackQuality? get activeQuality => null;

  @override
  bool get hasVideoFrame =>
      _controller?.value.isInitialized ?? false;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  double get aspectRatio {
    final ar = _controller?.value.aspectRatio ?? 0;
    return ar > 0 ? ar : 16 / 9;
  }


  @override
  String? get error => _controller?.value.errorDescription;

  @override
  Widget buildSurface(GlobalKey surfaceKey) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return vp.VideoPlayer(controller);
  }

  @override
  Future<void> play() => _controller?.play() ?? Future.value();

  @override
  Future<void> pause() => _controller?.pause() ?? Future.value();

  @override
  Future<void> seek(Duration position) =>
      _controller?.seekTo(position) ?? Future.value();

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  @override
  Future<void> applyQuality(PlaybackQuality quality) async {
    // Not supported: without a manifest engine there is no second track to
    // switch to, and re-opening a single URL would restart from zero.
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
