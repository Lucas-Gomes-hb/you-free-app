import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import 'download_manager.dart';
import 'playlist_service.dart';

class RepertoireEntry {
  final String videoId;
  final VideoModel video;
  final DateTime lastPlayedAt;
  final int playCount;

  const RepertoireEntry({
    required this.videoId,
    required this.video,
    required this.lastPlayedAt,
    required this.playCount,
  });

  RepertoireEntry copyWith({DateTime? lastPlayedAt, int? playCount}) {
    return RepertoireEntry(
      videoId: videoId,
      video: video,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'video': video.toJson(),
    'lastPlayedAt': lastPlayedAt.millisecondsSinceEpoch,
    'playCount': playCount,
  };

  factory RepertoireEntry.fromJson(Map<String, dynamic> json) {
    return RepertoireEntry(
      videoId: json['videoId'] as String,
      video: VideoModel.fromJson(json['video'] as Map<String, dynamic>),
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(json['lastPlayedAt'] as int),
      playCount: json['playCount'] as int,
    );
  }
}

/// Maintains a rolling list of up to 100 short tracks (≤ 6 min) that are
/// auto-downloaded for offline listening. Evicts the least-played entry when full.
class RepertoireService extends ChangeNotifier {
  static const _key = 'yf_repertoire';
  static const _maxItems = 100;
  static const _maxDurationSecs = 360; // 6 minutes

  final PlaylistService _playlistService;
  final List<RepertoireEntry> _entries = [];

  RepertoireService(this._playlistService) {
    _load();
  }

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
        _evictOne();
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

  void _evictOne() {
    if (_entries.isEmpty) return;
    // Sort ascending: fewest plays first, then oldest play date as tiebreaker
    _entries.sort((a, b) {
      final cmp = a.playCount.compareTo(b.playCount);
      return cmp != 0 ? cmp : a.lastPlayedAt.compareTo(b.lastPlayedAt);
    });
    _entries.removeAt(0);
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
