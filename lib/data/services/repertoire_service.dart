import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import 'download_manager.dart';
import 'playlist_service.dart';
import 'settings_service.dart';

class RepertoireEntry {
  final String videoId;
  final VideoModel video;
  final DateTime lastPlayedAt;
  final int playCount;
  final int skipCount;

  const RepertoireEntry({
    required this.videoId,
    required this.video,
    required this.lastPlayedAt,
    required this.playCount,
    this.skipCount = 0,
  });

  RepertoireEntry copyWith({DateTime? lastPlayedAt, int? playCount, int? skipCount}) {
    return RepertoireEntry(
      videoId: videoId,
      video: video,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'video': video.toJson(),
    'lastPlayedAt': lastPlayedAt.millisecondsSinceEpoch,
    'playCount': playCount,
    'skipCount': skipCount,
  };

  factory RepertoireEntry.fromJson(Map<String, dynamic> json) {
    return RepertoireEntry(
      videoId: json['videoId'] as String,
      video: VideoModel.fromJson(json['video'] as Map<String, dynamic>),
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastPlayedAt'] as int)
          : DateTime.now(),
      playCount: (json['playCount'] as int?) ?? 0,
      skipCount: (json['skipCount'] as int?) ?? 0,
    );
  }
}

/// Maintains a rolling list of tracks that are auto-downloaded for offline
/// listening. When the limit is reached the least-played + oldest entry is
/// evicted and its file deleted from disk (unless manually downloaded by user).
class RepertoireService extends ChangeNotifier {
  static const _key = 'yf_repertoire';
  static const _maxDurationSecs = 360; // 6 minutes

  final PlaylistService _playlistService;
  final SettingsService _settingsService;
  final List<RepertoireEntry> _entries = [];

  RepertoireService(this._playlistService, this._settingsService) {
    _load();
  }

  int get _maxItems => _settingsService.autoDownloadLimit;

  List<RepertoireEntry> get entries => List.unmodifiable(_entries);

  int get count => _entries.length;

  bool contains(String videoId) => _entries.any((e) => e.videoId == videoId);

  /// Called every time the user plays a video. If the video qualifies (duration ≤ 6 min),
  /// adds it to the repertoire (or updates play count) and triggers a background download.
  Future<void> touch(VideoModel video, DownloadManager downloadManager) async {
    // Only exclude if we know for certain the video is longer than 6 minutes
    if (video.duration != null && video.duration! > _maxDurationSecs) return;

    final idx = _entries.indexWhere((e) => e.videoId == video.id);
    if (idx >= 0) {
      _entries[idx] = _entries[idx].copyWith(
        lastPlayedAt: DateTime.now(),
        playCount: _entries[idx].playCount + 1,
      );
    } else {
      if (_entries.length >= _maxItems) {
        _evictOne(downloadManager);
      }
      _entries.add(RepertoireEntry(
        videoId: video.id,
        video: video,
        lastPlayedAt: DateTime.now(),
        playCount: 1,
      ));
      // Trigger download and playlist add without awaiting — runs in the background
      downloadManager.download(video, autoDownload: true);
      _addToAutoPlaylist(video);
    }

    await _persist();
    notifyListeners();
  }

  Future<void> _addToAutoPlaylist(VideoModel video) async {
    final playlist = await _playlistService.getOrCreateAutoDownloads();
    await _playlistService.addTrack(playlist.id, video);
  }

  /// Called when the user manually skips a video. Increments the skip count.
  Future<void> skip(VideoModel video) async {
    final idx = _entries.indexWhere((e) => e.videoId == video.id);
    if (idx < 0) return;
    _entries[idx] = _entries[idx].copyWith(
      skipCount: _entries[idx].skipCount + 1,
    );
    await _persist();
    notifyListeners();
  }

  /// Evicts the worst entry: oldest play date first, then lowest net score
  /// (playCount - skipCount), then alphabetical by title as final tiebreaker.
  void _evictOne(DownloadManager downloadManager) {
    if (_entries.isEmpty) return;
    _entries.sort((a, b) {
      final timeCmp = a.lastPlayedAt.compareTo(b.lastPlayedAt);
      if (timeCmp != 0) return timeCmp;

      final netA = a.playCount - a.skipCount;
      final netB = b.playCount - b.skipCount;
      final netCmp = netA.compareTo(netB);
      if (netCmp != 0) return netCmp;

      return a.video.title.compareTo(b.video.title);
    });
    final evicted = _entries.removeAt(0);
    if (!downloadManager.isManualDownload(evicted.videoId)) {
      downloadManager.delete(evicted.videoId);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    for (final s in raw) {
      try {
        _entries.add(RepertoireEntry.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    if (_entries.isNotEmpty) notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _entries.map((e) => jsonEncode(e.toJson())).toList());
  }
}
