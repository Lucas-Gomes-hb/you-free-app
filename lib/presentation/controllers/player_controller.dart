import 'package:mobx/mobx.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../data/models/video_model.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/history_service.dart';
import '../../data/services/audio_handler.dart';
import '../../data/services/download_manager.dart';
import '../../data/services/progress_service.dart';
import '../../data/services/lyrics_service.dart';
import '../../data/services/repertoire_service.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  final VideoRepository _repository;
  final HistoryService _historyService;
  final YouFreeAudioHandler _handler;
  final ProgressService _progressService;
  final DownloadManager _downloadManager;
  final RepertoireService _repertoireService;

  Function(VideoModel)? onVideoLoaded;

  // YouTube CDN URLs expire ~6h; we use a 4h TTL to match the API-side cache
  static const _kStreamTtlMs = 4 * 3600 * 1000;
  final Map<String, StreamInfo> _streamCache = {};
  final Map<String, int> _streamCacheTs = {};

  // Tracks video IDs whose video stream URL has already been pre-fetched
  final Set<String> _videoPrefetched = {};

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  // When set, overrides auto-fetched suggestions (used by Play All / Shuffle)
  List<VideoModel>? _queueOverride;

  bool _isRecovering = false;

  // Incremented on every load attempt; lets concurrent loads detect they've been superseded
  int _loadGeneration = 0;

  // In-session back-navigation stack (not persisted)
  final List<VideoModel> _playHistory = [];
  bool _skipHistoryPush = false;

  // Throttle position updates to ~300 ms to reduce MobX chatter
  int _lastPositionMs = 0;
  int _lastSaveMs = 0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processingSub;

  _PlayerController(
    this._repository,
    this._historyService,
    this._handler,
    this._progressService,
    this._downloadManager,
    this._repertoireService,
  ) {
    _handler.onSkipToNext = skipToNext;
    _handler.onSkipToPrevious = skipToPrevious;
    _handler.onPlaybackError = _recoverPlayback;

    _positionSub = _handler.player.positionStream.listen((pos) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPositionMs < 300) return;
      _lastPositionMs = now;
      position = pos;
      if (now - _lastSaveMs >= 10000 && currentVideo != null && pos.inSeconds > 0) {
        _lastSaveMs = now;
        _progressService.save(currentVideo!.id, pos.inSeconds, duration.inSeconds);
      }
    });
    _durationSub = _handler.player.durationStream.listen((dur) {
      if (dur != null) {
        duration = dur;
        _handler.updateDuration(dur);
      }
    });
    _playingSub = _handler.player.playingStream.listen((playing) {
      isPlaying = playing;
    });
    _processingSub = _handler.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !isLoading) {
        if (suggestions.isNotEmpty) {
          advanceInQueue(suggestions.first);
        } else if (currentVideo != null) {
          _startRadioFromCurrent();
        }
      }
    });
  }

  @observable
  VideoModel? currentVideo;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool isPlaying = false;

  @observable
  Duration position = Duration.zero;

  @observable
  Duration duration = Duration.zero;

  @observable
  ObservableList<VideoModel> suggestions = ObservableList<VideoModel>();

  @observable
  bool isSuggestionsLoading = false;

  @observable
  bool isVideoMode = false;

  @observable
  bool lyricsLoading = false;

  @observable
  bool lyricsLoaded = false;

  @observable
  String? plainLyrics;

  @observable
  String? syncedLyrics;

  @action
  Future<void> loadLyrics(String title, String artist) async {
    lyricsLoading = true;
    lyricsLoaded = false;
    plainLyrics = null;
    syncedLyrics = null;
    try {
      final result = await _repository.getLyrics(title, artist);
      plainLyrics = result['plain_lyrics'] as String?;
      syncedLyrics = result['synced_lyrics'] as String?;
    } catch (_) {
    } finally {
      lyricsLoading = false;
      lyricsLoaded = true;
    }
  }

  @computed
  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  bool isCurrentVideo(String videoId) => currentVideo?.id == videoId;

  void _pushHistory(VideoModel? video) {
    if (video == null) return;
    _playHistory.add(video);
    if (_playHistory.length > 50) _playHistory.removeAt(0);
  }

  void _saveCurrentProgress() {
    if (currentVideo == null) return;
    final pos = isVideoMode ? (_videoController?.value.position ?? position) : position;
    final dur = isVideoMode ? (_videoController?.value.duration ?? duration) : duration;
    if (pos.inSeconds > 0) {
      _progressService.save(currentVideo!.id, pos.inSeconds, dur.inSeconds);
    }
  }

  StreamInfo? _getCachedStream(String videoId) {
    final ts = _streamCacheTs[videoId];
    if (ts != null && DateTime.now().millisecondsSinceEpoch - ts > _kStreamTtlMs) {
      _streamCache.remove(videoId);
      _streamCacheTs.remove(videoId);
      return null;
    }
    return _streamCache[videoId];
  }

  void _cacheStream(String videoId, StreamInfo info) {
    _streamCache[videoId] = info;
    _streamCacheTs[videoId] = DateTime.now().millisecondsSinceEpoch;
    if (_streamCache.length > 40) {
      final oldest = _streamCacheTs.entries.reduce((a, b) => a.value < b.value ? a : b).key;
      _streamCache.remove(oldest);
      _streamCacheTs.remove(oldest);
    }
  }

  // Returns true if playback position should be restored for this video.
  // Short tracks (≤ 6 min with known duration) always start from the beginning.
  bool _shouldResume(VideoModel video) {
    final d = video.duration;
    return d == null || d > 360;
  }

  // Pre-fetches audio URLs for the next [count] songs into local cache in parallel
  // and tells the server to warm its cache for double that window.
  void _prefetchAhead(int count) {
    if (suggestions.isEmpty) return;
    final songs = suggestions.take(count).toList();
    // Warm server cache for a larger lookahead (server processes in background threads)
    final serverIds = suggestions.take(count * 2).map((v) => v.id).toList();
    _repository.warmServerCache(serverIds);
    // Fetch into local Flutter cache in parallel
    for (final video in songs) {
      if (_streamCache.containsKey(video.id)) continue;
      _repository.getStreamInfo(video.id).then((info) {
        _cacheStream(video.id, info);
      }).catchError((_) {});
    }
  }

  // Warms the API video cache so switchToVideoMode() is instant
  void _prefetchVideoUrl(String videoId) {
    if (_videoPrefetched.contains(videoId)) return;
    _videoPrefetched.add(videoId);
    _repository.getStreamInfo(videoId, format: 'video').then((_) {}).catchError((_) {
      _videoPrefetched.remove(videoId);
    });
  }

  @action
  Future<void> loadVideo(VideoModel video) async {
    if (currentVideo?.id == video.id && errorMessage == null) return;
    final gen = ++_loadGeneration;

    _saveCurrentProgress();
    await _exitVideoMode();
    if (gen != _loadGeneration) return;
    if (!_skipHistoryPush) _pushHistory(currentVideo);

    isLoading = true;
    errorMessage = null;
    currentVideo = video;
    position = Duration.zero;
    duration = Duration.zero;
    lyricsLoaded = false;
    plainLyrics = null;
    syncedLyrics = null;

    try {
      final localPath = _downloadManager.localPathFor(video.id, hint: video);
      final AudioSource audioSource;

      if (localPath != null) {
        audioSource = AudioSource.uri(Uri.file(localPath));
      } else {
        final cached = _getCachedStream(video.id);
        final streamInfo = cached ?? await _repository.getStreamInfo(video.id);
        if (gen != _loadGeneration) return;
        if (cached == null) _cacheStream(video.id, streamInfo);

        final format = streamInfo.bestAudio;
        if (format == null) {
          errorMessage = 'Formato de áudio não encontrado';
          isLoading = false;
          return;
        }
        // ignore: experimental_member_use
        audioSource = LockCachingAudioSource(Uri.parse(format.url));
      }

      await _handler.playNow(
        audioSource,
        MediaItem(
          id: video.id,
          title: video.title,
          artist: video.uploader ?? '',
          artUri: video.thumbnail != null ? Uri.tryParse(video.thumbnail!) : null,
        ),
      );

      isLoading = false;
      _handler.play();

      if (_shouldResume(video)) {
        final savedPos = await _progressService.get(video.id);
        if (gen != _loadGeneration) return;
        if (savedPos != null && savedPos > 0) {
          await _handler.seek(Duration(seconds: savedPos));
        }
      }

      _historyService.add(video);
      _repertoireService.touch(video, _downloadManager);
      onVideoLoaded?.call(video);
      _fetchSuggestions(video);
      _prefetchVideoUrl(video.id);
    } catch (e) {
      if (gen == _loadGeneration) {
        errorMessage = e.toString();
        isLoading = false;
      }
    }
  }

  void _startRadioFromCurrent() {
    final video = currentVideo;
    if (video == null) return;
    runInAction(() { isSuggestionsLoading = true; });
    _repository.getSuggestions(video.id, title: video.title, uploader: video.uploader ?? '').then((results) {
      runInAction(() {
        suggestions = ObservableList.of(results);
        isSuggestionsLoading = false;
      });
      if (suggestions.isNotEmpty) advanceInQueue(suggestions.first);
    }).catchError((_) {
      runInAction(() { isSuggestionsLoading = false; });
    });
  }

  void _fetchSuggestions(VideoModel video) {
    if (_queueOverride != null) {
      final queue = _queueOverride!;
      _queueOverride = null;
      runInAction(() {
        suggestions = ObservableList.of(queue);
        isSuggestionsLoading = false;
      });
      _prefetchAhead(4);
      return;
    }
    runInAction(() { isSuggestionsLoading = true; });
    _repository
        .getSuggestions(video.id, title: video.title, uploader: video.uploader ?? '')
        .then((results) {
      runInAction(() {
        suggestions = ObservableList.of(results);
        isSuggestionsLoading = false;
      });
      _prefetchAhead(4);
    }).catchError((_) {
      runInAction(() { isSuggestionsLoading = false; });
    });
  }

  void playFromQueue(List<VideoModel> queue) {
    if (queue.isEmpty) return;
    final remaining = queue.length > 1 ? queue.skip(1).toList() : <VideoModel>[];
    _queueOverride = remaining.isNotEmpty ? remaining : null;
    if (remaining.isNotEmpty) {
      // Warm server cache for the entire queue upfront — server processes in background
      _repository.warmServerCache(remaining.map((v) => v.id).toList());
    }
    // If the first song is already playing, just install the new queue without restarting
    if (currentVideo?.id == queue.first.id && errorMessage == null) {
      runInAction(() {
        suggestions = ObservableList.of(remaining);
        isSuggestionsLoading = false;
      });
      _queueOverride = null;
      if (remaining.isNotEmpty) _prefetchAhead(4);
      return;
    }
    loadVideo(queue.first);
  }

  Future<void> _loadStreamOnly(VideoModel video) async {
    await _exitVideoMode();
    runInAction(() {
      isLoading = true;
      errorMessage = null;
      currentVideo = video;
      position = Duration.zero;
      duration = Duration.zero;
    });
    try {
      final localPath = _downloadManager.localPathFor(video.id, hint: video);
      final AudioSource audioSource;

      if (localPath != null) {
        audioSource = AudioSource.uri(Uri.file(localPath));
      } else {
        final cached = _getCachedStream(video.id);
        final streamInfo = cached ?? await _repository.getStreamInfo(video.id);
        if (cached == null) _cacheStream(video.id, streamInfo);
        final format = streamInfo.bestAudio;
        if (format == null) {
          runInAction(() { errorMessage = 'Formato de áudio não encontrado'; isLoading = false; });
          return;
        }
        // ignore: experimental_member_use
        audioSource = LockCachingAudioSource(Uri.parse(format.url));
      }

      await _handler.playNow(
        audioSource,
        MediaItem(
          id: video.id, title: video.title, artist: video.uploader ?? '',
          artUri: video.thumbnail != null ? Uri.tryParse(video.thumbnail!) : null,
        ),
      );
      runInAction(() { isLoading = false; });
      _handler.play();
      _historyService.add(video);
      _repertoireService.touch(video, _downloadManager);
      onVideoLoaded?.call(video);
      _prefetchAhead(4);
      _prefetchVideoUrl(video.id);
    } catch (e) {
      runInAction(() { errorMessage = e.toString(); isLoading = false; });
    }
  }

  Future<void> skipToPrevious() async {
    if (position.inSeconds > 15) {
      await seek(Duration.zero);
      return;
    }
    if (_playHistory.isNotEmpty) {
      if (currentVideo != null) {
        _repertoireService.skip(currentVideo!);
      }
      await _loadStreamOnly(_playHistory.removeLast());
    } else {
      await seek(Duration.zero);
    }
  }

  /// Advances within the current radio queue without fetching a new one.
  /// Use this when tapping a suggestion or pressing skip — the queue stays intact.
  /// Use [loadVideo] only for fresh picks (search, home feed).
  Future<void> advanceInQueue(VideoModel video) async {
    if (currentVideo?.id == video.id && errorMessage == null) return;
    final gen = ++_loadGeneration;

    _saveCurrentProgress();
    await _exitVideoMode();
    if (gen != _loadGeneration) return;
    _pushHistory(currentVideo);

    final idx = suggestions.indexWhere((v) => v.id == video.id);

    runInAction(() {
      isLoading = true;
      errorMessage = null;
      currentVideo = video;
      position = Duration.zero;
      duration = Duration.zero;
      lyricsLoaded = false;
      plainLyrics = null;
      syncedLyrics = null;
      if (idx >= 0) {
        suggestions = ObservableList.of(suggestions.skip(idx + 1));
      }
    });

    try {
      final localPath = _downloadManager.localPathFor(video.id, hint: video);
      final AudioSource audioSource;

      if (localPath != null) {
        audioSource = AudioSource.uri(Uri.file(localPath));
      } else {
        final cached = _getCachedStream(video.id);
        final streamInfo = cached ?? await _repository.getStreamInfo(video.id);
        if (gen != _loadGeneration) return;
        if (cached == null) _cacheStream(video.id, streamInfo);

        final format = streamInfo.bestAudio;
        if (format == null) {
          runInAction(() {
            errorMessage = 'Formato de áudio não encontrado';
            isLoading = false;
          });
          return;
        }
        // ignore: experimental_member_use
        audioSource = LockCachingAudioSource(Uri.parse(format.url));
      }

      await _handler.playNow(
        audioSource,
        MediaItem(
          id: video.id,
          title: video.title,
          artist: video.uploader ?? '',
          artUri: video.thumbnail != null ? Uri.tryParse(video.thumbnail!) : null,
        ),
      );

      runInAction(() { isLoading = false; });
      _handler.play();
      if (_shouldResume(video)) {
        final savedPos = await _progressService.get(video.id);
        if (gen != _loadGeneration) return;
        if (savedPos != null && savedPos > 0) {
          await _handler.seek(Duration(seconds: savedPos));
        }
      }
      _historyService.add(video);
      _repertoireService.touch(video, _downloadManager);
      onVideoLoaded?.call(video);
      _prefetchAhead(4);
      _prefetchVideoUrl(video.id);
    } catch (e) {
      if (gen == _loadGeneration) {
        runInAction(() { errorMessage = e.toString(); isLoading = false; });
      }
    }
  }

  @action
  Future<void> skipToNext() async {
    if (currentVideo != null) {
      _repertoireService.skip(currentVideo!);
    }
    if (suggestions.isNotEmpty) await advanceInQueue(suggestions.first);
  }

  @action
  Future<void> pause() async {
    if (!isPlaying) return;
    if (isVideoMode && _videoController != null) {
      await _videoController!.pause();
      isPlaying = false;
    } else {
      await _handler.pause();
    }
  }

  @action
  Future<void> togglePlayPause() async {
    if (isVideoMode && _videoController != null) {
      if (isPlaying) {
        await _videoController!.pause();
        isPlaying = false;
      } else {
        await _videoController!.play();
        isPlaying = true;
      }
    } else {
      if (isPlaying) {
        await _handler.pause();
      } else {
        await _handler.play();
      }
    }
  }

  @action
  Future<void> seek(Duration pos) async {
    if (isVideoMode && _videoController != null) {
      await _videoController!.seekTo(pos);
    } else {
      await _handler.seek(pos);
    }
  }

  @action
  Future<void> switchToVideoMode() async {
    if (currentVideo == null || isVideoMode) return;
    final savedSecs = await _progressService.get(currentVideo!.id);
    final savedPosition = savedSecs != null ? Duration(seconds: savedSecs) : position;

    runInAction(() { isLoading = true; });
    try {
      final streamInfo = await _repository.getStreamInfo(currentVideo!.id, format: 'video');
      if (streamInfo.videoUrl == null) {
        runInAction(() { isLoading = false; });
        return;
      }

      final vc = VideoPlayerController.networkUrl(Uri.parse(streamInfo.videoUrl!));
      await vc.initialize();
      await vc.seekTo(savedPosition);
      vc.addListener(_onVideoUpdate);

      await _handler.pause();
      _videoController = vc;
      await vc.play();

      runInAction(() {
        isVideoMode = true;
        isLoading = false;
        isPlaying = true;
      });
    } catch (e) {
      runInAction(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @action
  Future<void> switchToAudioMode() async {
    if (!isVideoMode || _videoController == null) return;
    final videoPos = _videoController!.value.position;
    await _exitVideoMode();
    await _handler.seek(videoPos);
    await _handler.play();
    runInAction(() { isPlaying = true; });
  }

  Future<void> _exitVideoMode() async {
    if (!isVideoMode || _videoController == null) return;
    _videoController!.removeListener(_onVideoUpdate);
    await _videoController!.pause();
    await _videoController!.dispose();
    _videoController = null;
    runInAction(() { isVideoMode = false; });
  }

  void _onVideoUpdate() {
    final v = _videoController?.value;
    if (v == null) return;

    if (v.position >= v.duration && v.duration > Duration.zero) {
      _exitVideoAndAdvance();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPositionMs >= 300) {
      _lastPositionMs = now;
      runInAction(() {
        position = v.position;
        duration = v.duration;
        isPlaying = v.isPlaying;
      });
      if (now - _lastSaveMs >= 10000 && currentVideo != null && v.position.inSeconds > 0) {
        _lastSaveMs = now;
        _progressService.save(currentVideo!.id, v.position.inSeconds, v.duration.inSeconds);
      }
    }
  }

  Future<void> _exitVideoAndAdvance() async {
    _videoController?.removeListener(_onVideoUpdate);
    await _videoController?.dispose();
    _videoController = null;
    runInAction(() { isVideoMode = false; });
    if (suggestions.isNotEmpty) {
      await advanceInQueue(suggestions.first);
    }
  }

  // Clears cached URL and reloads after a mid-playback stream failure
  Future<void> _recoverPlayback() async {
    if (_isRecovering || currentVideo == null || isLoading) return;
    _isRecovering = true;
    final video = currentVideo!;
    _streamCache.remove(video.id);
    runInAction(() { errorMessage = 'Reconectando...'; });
    try {
      _skipHistoryPush = true;
      await loadVideo(video);
    } finally {
      _skipHistoryPush = false;
      _isRecovering = false;
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _processingSub?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.dispose();
    _handler.dispose();
  }
}
