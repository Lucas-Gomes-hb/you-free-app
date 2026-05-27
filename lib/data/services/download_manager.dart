import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import 'api_service.dart';
import 'playlist_service.dart';

enum DownloadStatus { none, downloading, done, error }

class DownloadInfo {
  final DownloadStatus status;
  final double progress;
  final String? localPath;

  const DownloadInfo(this.status, [this.progress = 0, this.localPath]);
}

class DownloadManager extends ChangeNotifier {
  final ApiService _apiService;
  final PlaylistService _playlistService;
  final Dio _dio = Dio();

  final Map<String, DownloadInfo> _downloads = {};
  final Map<String, CancelToken> _tokens = {};

  Set<String> _persistedIds = {};
  Map<String, String> _persistedPaths = {};
  // Stores the full VideoModel for every downloaded video (for playlist sync + path recovery)
  Map<String, VideoModel> _persistedVideos = {};
  // IDs downloaded manually by the user (not auto-downloaded by RepertoireService)
  Set<String> _manualIds = {};

  // Cached downloads directory path — avoids repeated async lookups
  String? _dirPath;

  // Completes when _init() finishes — syncToPlaylists() awaits this
  final _readyCompleter = Completer<void>();
  Future<void> get _ready => _readyCompleter.future;

  DownloadManager(this._apiService, this._playlistService) {
    _init();
  }

  Future<void> _init() async {
    await _loadPersisted();
    _dirPath = (await _downloadsDir()).path;
    _readyCompleter.complete();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  DownloadInfo infoFor(String videoId) {
    final inMemory = _downloads[videoId];
    if (inMemory != null) return inMemory;
    if (_persistedIds.contains(videoId)) {
      return DownloadInfo(DownloadStatus.done, 1.0, _persistedPaths[videoId]);
    }
    return const DownloadInfo(DownloadStatus.none);
  }

  bool isDownloaded(String videoId) {
    final s = _downloads[videoId]?.status;
    return s == DownloadStatus.done || _persistedIds.contains(videoId);
  }

  /// Returns the local file path for a downloaded video, or null if unavailable.
  /// [hint] is the VideoModel of the video — used to recover paths for legacy
  /// downloads that were saved before path/VideoModel persistence was added.
  String? localPathFor(String videoId, {VideoModel? hint}) {
    // In-memory path (current session)
    final inMemory = _downloads[videoId];
    if (inMemory?.status == DownloadStatus.done && inMemory?.localPath != null) {
      if (File(inMemory!.localPath!).existsSync()) return inMemory.localPath;
    }
    // Persisted path
    final persisted = _persistedPaths[videoId];
    if (persisted != null) {
      if (File(persisted).existsSync()) return persisted;
      // File was deleted from disk — clean up stale record
      _persistedIds.remove(videoId);
      _persistedPaths.remove(videoId);
      _persistedVideos.remove(videoId);
      _manualIds.remove(videoId);
      _persistAllAsync();
      return null;
    }
    // No stored path — try to find the file using stored or hinted VideoModel
    final video = _persistedVideos[videoId] ?? hint;
    if (video != null && _dirPath != null && _persistedIds.contains(videoId)) {
      return _scanForFile(video);
    }
    return null;
  }

  VideoModel? videoFor(String videoId) => _persistedVideos[videoId];

  /// Downloads [video]. Pass [autoDownload] = true when triggered by RepertoireService
  /// so it does NOT appear in the "Downloads" manual playlist.
  Future<void> download(VideoModel video, {bool autoDownload = false}) async {
    final id = video.id;
    if (isDownloaded(id)) {
      // Even if already downloaded, ensure it's in the right playlist
      if (!autoDownload && !_playlistContains('Downloads', id)) {
        _addToPlaylist('Downloads', video);
      }
      return;
    }
    if (_downloads[id]?.status == DownloadStatus.downloading) return;

    _set(id, const DownloadInfo(DownloadStatus.downloading));
    _persistedVideos[id] = video;

    try {
      final streamInfo = await _apiService.getStreamInfo(id);
      final format = streamInfo.bestAudio;
      if (format == null) {
        _set(id, const DownloadInfo(DownloadStatus.error));
        return;
      }

      final dir = await _downloadsDir();
      final filename = _buildFilename(video.title, video.uploader ?? '', format.ext);
      final path = '${dir.path}/$filename';

      final token = CancelToken();
      _tokens[id] = token;

      await _dio.download(
        format.url,
        path,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _set(id, DownloadInfo(DownloadStatus.downloading, received / total));
          }
        },
      );

      _tokens.remove(id);
      _set(id, DownloadInfo(DownloadStatus.done, 1.0, path));

      if (!autoDownload) _manualIds.add(id);
      await _persistAllAsync(addId: id, path: path);

      if (!autoDownload) _addToPlaylist('Downloads', video);
    } catch (e) {
      _tokens.remove(id);
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _set(id, const DownloadInfo(DownloadStatus.none));
      } else {
        _set(id, const DownloadInfo(DownloadStatus.error));
      }
    }
  }

  void cancel(String videoId) {
    _tokens[videoId]?.cancel('Cancelado pelo usuário');
  }

  bool isManualDownload(String videoId) => _manualIds.contains(videoId);

  /// Deletes a downloaded video: removes the file from disk and clears all
  /// persisted state. Also removes the track from any downloads playlist.
  Future<void> delete(String videoId) async {
    // Cancel any in-progress download first
    _tokens[videoId]?.cancel('Deletado pelo usuário');
    _tokens.remove(videoId);

    // Delete file from disk (persisted path)
    final persistedPath = _persistedPaths[videoId];
    if (persistedPath != null) {
      try {
        final file = File(persistedPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    // Also try in-memory path (may differ from persisted during same session)
    final memPath = _downloads[videoId]?.localPath;
    if (memPath != null && memPath != persistedPath) {
      try {
        final file = File(memPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    // Clear from in-memory map
    _downloads.remove(videoId);

    // Persist the removal
    await _persistAllAsync(addId: videoId, remove: true);

    // Remove from both downloads playlists
    await _removeFromPlaylist('Downloads', videoId);
    await _removeFromPlaylist('Downloads Automáticos', videoId);

    notifyListeners();
  }

  /// Ensures all MANUAL downloads appear in the "Downloads" playlist.
  /// Auto-downloads (via RepertoireService) go to "Downloads Automáticos" only.
  /// Call once at startup after PlaylistService.load() has completed.
  Future<void> syncToPlaylists() async {
    // Wait for internal state to finish loading before accessing it
    await _ready;

    for (final id in _manualIds) {
      if (!_persistedIds.contains(id)) continue;
      final video = _persistedVideos[id];
      if (video == null) continue;
      if (localPathFor(id, hint: video) == null) continue;
      if (!_playlistContains('Downloads', id)) {
        await _addToPlaylist('Downloads', video);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  bool _playlistContains(String playlistName, String videoId) {
    try {
      final pl = _playlistService.playlists.firstWhere((p) => p.name == playlistName);
      return pl.tracks.any((t) => t.id == videoId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _addToPlaylist(String playlistName, VideoModel video) async {
    try {
      final pl = await _playlistService.getOrCreate(playlistName);
      await _playlistService.addTrack(pl.id, video);
    } catch (_) {}
  }

  Future<void> _removeFromPlaylist(String playlistName, String videoId) async {
    try {
      final pl = _playlistService.playlists.firstWhere((p) => p.name == playlistName);
      await _playlistService.removeTrack(pl.id, videoId);
    } catch (_) {}
  }

  /// Tries to find an existing file for [video] in the downloads directory
  /// by attempting all known audio extensions. Used for legacy downloads.
  String? _scanForFile(VideoModel video) {
    if (_dirPath == null) return null;
    const exts = ['m4a', 'mp3', 'opus', 'webm', 'ogg', 'mp4'];
    for (final ext in exts) {
      final filename = _buildFilename(video.title, video.uploader ?? '', ext);
      final path = '$_dirPath/$filename';
      if (File(path).existsSync()) {
        // Store recovered path so we don't scan again
        _persistedPaths[video.id] = path;
        _persistAllAsync();
        return path;
      }
    }
    return null;
  }

  Future<Directory> _downloadsDir() async {
    Directory? base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/YouFree');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _buildFilename(String title, String uploader, String ext) {
    final raw = uploader.isNotEmpty ? '$uploader - $title' : title;
    final clean = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final name = clean.length > 120 ? clean.substring(0, 120) : clean;
    return '$name.$ext';
  }

  void _set(String id, DownloadInfo info) {
    _downloads[id] = info;
    notifyListeners();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();

    _persistedIds = Set.of(prefs.getStringList('yf_downloaded_ids') ?? []);

    final pathsJson = prefs.getString('yf_download_paths');
    if (pathsJson != null) {
      try {
        final map = jsonDecode(pathsJson) as Map<String, dynamic>;
        _persistedPaths = map.map((k, v) => MapEntry(k, v as String));
      } catch (_) {}
    }

    final videosJson = prefs.getString('yf_download_videos');
    if (videosJson != null) {
      try {
        final map = jsonDecode(videosJson) as Map<String, dynamic>;
        _persistedVideos = map.map((k, v) =>
            MapEntry(k, VideoModel.fromJson(v as Map<String, dynamic>)));
      } catch (_) {}
    }

    _manualIds = Set.of(prefs.getStringList('yf_manual_ids') ?? []);

    if (_persistedIds.isNotEmpty) notifyListeners();
  }

  Future<void> _persistAllAsync({String? addId, String? path, bool remove = false}) async {
    if (addId != null) {
      if (remove) {
        _persistedIds.remove(addId);
        _persistedPaths.remove(addId);
        _persistedVideos.remove(addId);
        _manualIds.remove(addId);
      } else {
        _persistedIds.add(addId);
        if (path != null) _persistedPaths[addId] = path;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setStringList('yf_downloaded_ids', _persistedIds.toList()),
      prefs.setString('yf_download_paths', jsonEncode(_persistedPaths)),
      prefs.setString(
          'yf_download_videos',
          jsonEncode(_persistedVideos.map((k, v) => MapEntry(k, v.toJson())))),
      prefs.setStringList('yf_manual_ids', _manualIds.toList()),
    ]);
  }
}
