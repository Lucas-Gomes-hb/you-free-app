import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/video_model.dart';
import '../data/repositories/video_repository.dart';
import '../data/services/history_service.dart';
import '../data/services/progress_service.dart';
import '../data/services/youtube/chunked_audio_source.dart';

class DesktopController extends ChangeNotifier {
  final VideoRepository _repository;
  final HistoryService _historyService;
  final ProgressService _progressService;
  final AudioPlayer _player = AudioPlayer();

  /// YouTube CDN URLs only answer bounded range requests — an open-ended one
  /// stalls and is truncated mid-file — so they get a chunked source whenever
  /// the size is known. Without a size there is no range to bound, and the
  /// caching source is the only option left.
  AudioSource _buildAudioSource(StreamFormat format) {
    final size = format.filesize;
    if (size != null && size > 0) {
      return ChunkedAudioSource(
        url: format.url,
        sourceLength: size,
        contentType: _contentTypeFor(format.ext),
      );
    }
    // ignore: experimental_member_use
    return LockCachingAudioSource(Uri.parse(format.url));
  }

  String _contentTypeFor(String ext) => switch (ext) {
        'm4a' || 'mp4' => 'audio/mp4',
        'webm' || 'opus' => 'audio/webm',
        'mp3' => 'audio/mpeg',
        'ogg' => 'audio/ogg',
        _ => 'audio/mp4',
      };

  final Map<String, StreamInfo> _streamCache = {};
  int _loadGeneration = 0;
  final List<VideoModel> _playHistory = [];

  VideoModel? _currentVideo;
  VideoModel? get currentVideo => _currentVideo;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  List<VideoModel> _suggestions = [];
  List<VideoModel> get suggestions => _suggestions;

  bool _isSuggestionsLoading = false;
  bool get isSuggestionsLoading => _isSuggestionsLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<VideoModel> _searchResults = [];
  List<VideoModel> get searchResults => _searchResults;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<PlayerState>? _stateSub;

  DesktopController({
    required VideoRepository repository,
    required HistoryService historyService,
    required ProgressService progressService,
  })  : _repository = repository,
        _historyService = historyService,
        _progressService = progressService {
    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
    _playingSub = _player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_isLoading) {
        if (_suggestions.isNotEmpty) {
          advanceInQueue(_suggestions.first);
        }
      }
    });
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  bool isCurrentVideo(String videoId) => _currentVideo?.id == videoId;

  Future<void> loadVideo(VideoModel video) async {
    if (_currentVideo?.id == video.id && _errorMessage == null) return;
    final gen = ++_loadGeneration;

    _saveCurrentProgress();
    _pushHistory(_currentVideo);

    _isLoading = true;
    _errorMessage = null;
    _currentVideo = video;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      final cached = _getCachedStream(video.id);
      final streamInfo = cached ?? await _repository.getStreamInfo(video.id);
      if (gen != _loadGeneration) return;
      if (cached == null) _cacheStream(video.id, streamInfo);

      final format = streamInfo.bestAudio;
      if (format == null) {
        _errorMessage = 'Audio format not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _player.setAudioSource(_buildAudioSource(format));

      _isLoading = false;
      notifyListeners();
      _player.play();

      final savedPos = await _progressService.get(video.id);
      if (gen != _loadGeneration) return;
      if (savedPos != null && savedPos > 0) {
        await _player.seek(Duration(seconds: savedPos));
      }

      _historyService.add(video);
      _fetchSuggestions(video);
    } catch (e) {
      if (gen == _loadGeneration) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> advanceInQueue(VideoModel video) async {
    if (_currentVideo?.id == video.id && _errorMessage == null) return;
    final gen = ++_loadGeneration;

    _saveCurrentProgress();
    _pushHistory(_currentVideo);

    final idx = _suggestions.indexWhere((v) => v.id == video.id);

    _isLoading = true;
    _errorMessage = null;
    _currentVideo = video;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      final cached = _getCachedStream(video.id);
      final streamInfo = cached ?? await _repository.getStreamInfo(video.id);
      if (gen != _loadGeneration) return;
      if (cached == null) _cacheStream(video.id, streamInfo);

      final format = streamInfo.bestAudio;
      if (format == null) {
        _errorMessage = 'Audio format not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _player.setAudioSource(_buildAudioSource(format));

      if (idx >= 0) {
        _suggestions = _suggestions.skip(idx + 1).toList();
      }

      _isLoading = false;
      notifyListeners();
      _player.play();

      final savedPos = await _progressService.get(video.id);
      if (gen != _loadGeneration) return;
      if (savedPos != null && savedPos > 0) {
        await _player.seek(Duration(seconds: savedPos));
      }

      _historyService.add(video);
    } catch (e) {
      if (gen == _loadGeneration) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _fetchSuggestions(VideoModel video) {
    _isSuggestionsLoading = true;
    notifyListeners();
    _repository
        .getSuggestions(video.id, title: video.title, uploader: video.uploader ?? '')
        .then((results) {
      _suggestions = results;
      _isSuggestionsLoading = false;
      notifyListeners();
    }).catchError((_) {
      _isSuggestionsLoading = false;
      notifyListeners();
    });
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> skipToNext() async {
    if (_suggestions.isNotEmpty) {
      await advanceInQueue(_suggestions.first);
    }
  }

  Future<void> skipToPrevious() async {
    if (_position.inSeconds > 15) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_playHistory.isNotEmpty) {
      await loadVideo(_playHistory.removeLast());
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void _pushHistory(VideoModel? video) {
    if (video == null) return;
    _playHistory.add(video);
    if (_playHistory.length > 50) _playHistory.removeAt(0);
  }

  void _saveCurrentProgress() {
    if (_currentVideo == null) return;
    if (_position.inSeconds > 0) {
      _progressService.save(
        _currentVideo!.id,
        _position.inSeconds,
        _duration.inSeconds,
      );
    }
  }

  StreamInfo? _getCachedStream(String videoId) {
    return _streamCache[videoId];
  }

  void _cacheStream(String videoId, StreamInfo info) {
    _streamCache[videoId] = info;
    if (_streamCache.length > 40) {
      _streamCache.remove(_streamCache.keys.first);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> search() async {
    if (_searchQuery.trim().isEmpty) return;
    _isSearching = true;
    _searchResults = [];
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchVideos(_searchQuery);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    return await _repository.getSearchSuggestions(query);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
