import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class YouFreeAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Queue used for gapless playback — current track + pre-loaded next track.
  ConcatenatingAudioSource _queue = ConcatenatingAudioSource(children: []);
  final List<MediaItem> _mediaItems = [];

  Function()? onSkipToNext;
  Function()? onSkipToPrevious;
  Function()? onPlaybackError;
  Function(int index)? onTrackChanged;
  // Called every time playing state changes — used to sync PiP button icon
  void Function(bool playing)? onPlayingChanged;

  YouFreeAudioHandler() {
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (_, __) {
        _broadcastState();
        onPlaybackError?.call();
      },
    );
    _player.playingStream.listen((_) => _broadcastState());
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _mediaItems.length) {
        mediaItem.add(_mediaItems[index]);
        if (index > 0) onTrackChanged?.call(index);
      }
    });
  }

  AudioPlayer get player => _player;

  /// Replaces the queue with a single track and loads it (gapless slate cleared).
  Future<void> playNow(AudioSource source, MediaItem item) async {
    _mediaItems
      ..clear()
      ..add(item);
    _queue = ConcatenatingAudioSource(children: [source]);
    mediaItem.add(item);
    await _player.setAudioSource(_queue);
  }

  /// Appends the next track to the queue so just_audio transitions gaplessly.
  /// Replaces any previously queued (not yet played) item.
  Future<void> queueNext(AudioSource source, MediaItem item) async {
    final ci = _player.currentIndex ?? 0;
    while (_queue.length > ci + 1) {
      await _queue.removeAt(ci + 1);
      if (_mediaItems.length > ci + 1) _mediaItems.removeAt(ci + 1);
    }
    _mediaItems.add(item);
    await _queue.add(source);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => await onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => await onSkipToPrevious?.call();

  void updateDuration(Duration duration) {
    final current = mediaItem.value;
    if (current != null) mediaItem.add(current.copyWith(duration: duration));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  // Pause instead of stopping the service when the user swipes the notification.
  @override
  Future<void> onNotificationDeleted() async {
    await _player.pause();
  }

  void dispose() {
    _player.dispose();
  }

  void _broadcastState() {
    final playing = _player.playing;
    onPlayingChanged?.call(playing);
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }
}
