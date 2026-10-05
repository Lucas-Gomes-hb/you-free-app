import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';
import '../../data/services/history_service.dart';
import 'player_controller.dart';
import 'video_playback_controller.dart';
import 'video_watch_controller.dart';

/// The video experience, kept apart from the music player.
///
/// Lives as long as the app, like [PlayerController], so the video survives
/// the Watch page: backing out hands it to the mini player, and tapping the
/// mini player returns to the same playback without a reload. The audio
/// player is never asked to load anything here — it is only paused while a
/// video plays, and a video is paused (or closed) when audio takes over.
class VideoSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  VideoSessionController({
    required ContentSource source,
    required PlayerController playerController,
    required HistoryService historyService,
    required this.pipMode,
    this.onWatched,
  })  : _source = source,
        _playerController = playerController,
        _historyService = historyService,
        playback = VideoPlaybackController(repository: source) {
    WidgetsBinding.instance.addObserver(this);
    _audioReaction = reaction(
      (_) => _playerController.isPlaying,
      (bool playing) {
        if (playing) _yieldToAudio();
      },
    );
  }

  final ContentSource _source;
  final PlayerController _playerController;
  final HistoryService _historyService;

  /// True while the activity is in Picture-in-Picture.
  final ValueListenable<bool> pipMode;

  /// Called with every video that starts, so the music home can list it as
  /// recently played and open it back in the Watch page.
  final void Function(VideoModel video)? onWatched;

  final VideoPlaybackController playback;

  ReactionDisposer? _audioReaction;

  VideoModel? _current;
  VideoWatchController? _watch;
  int _watchPages = 0;

  /// Video open in the session, null when there is none.
  VideoModel? get current => _current;

  /// Header, "up next" and comments of [current], kept with the session so
  /// coming back from the mini player does not refetch them.
  VideoWatchController? get watch => _watch;

  bool get isActive => _current != null;

  /// Whether a Watch page is on screen. The mini player only takes over once
  /// it is gone.
  bool get isWatchPageOpen => _watchPages > 0;

  /// Called from the Watch page's initState and dispose.
  void attachWatchPage() {
    _watchPages++;
    _notify();
  }

  void detachWatchPage() {
    if (_watchPages > 0) _watchPages--;
    _notify();
  }

  bool _disposed = false;

  /// Notifies now, or after the frame when called while the tree is being
  /// built or torn down — which is where the Watch page attaches, opens and
  /// detaches. Listeners rebuilding mid-build is an assertion in Flutter.
  void _notify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  /// Opens [video]. The video already playing is kept as is, which is what
  /// lets the mini player expand back into the page without a reload.
  Future<void> open(VideoModel video) async {
    final alreadyOpen = _current?.id == video.id &&
        playback.videoId == video.id &&
        playback.error == null;
    if (alreadyOpen) return;

    _current = video;
    _watch = VideoWatchController(_source, video.id)..load();
    _notify();

    await _playerController.pause();
    await _historyService.add(video.copyWith(playedAsVideo: true));
    onWatched?.call(video);
    if (_current?.id != video.id) return;
    await playback.load(video.id);
  }

  /// Ends the session: the engine is released and the mini player goes back
  /// to the audio player.
  Future<void> close() async {
    if (_current == null) return;
    _current = null;
    _watch = null;
    _notify();
    await playback.stop();
  }

  Future<void> togglePlayPause() async {
    if (playback.isPlaying) {
      await playback.pause();
    } else {
      await _playerController.pause();
      await playback.play();
    }
  }

  Future<void> pause() => playback.pause();

  /// Audio started elsewhere (a track, the notification, a headset). Only one
  /// player runs at a time: an open page keeps the video paused in place, a
  /// minimized one is closed so the mini player shows the track again.
  void _yieldToAudio() {
    if (_current == null) return;
    if (isWatchPageOpen) {
      playback.pause();
    } else {
      close();
    }
  }

  /// The video stops when the app leaves the screen, unless it went to
  /// Picture-in-Picture. PiP only makes the activity inactive, never paused,
  /// so this does not fire for it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !pipMode.value) {
      playback.pause();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _audioReaction?.call();
    playback.dispose();
    super.dispose();
  }
}
