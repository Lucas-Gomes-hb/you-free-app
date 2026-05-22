import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_playlist.dart';
import '../models/video_model.dart';

class PlaylistService extends ChangeNotifier {
  static const _key = 'local_playlists';
  List<LocalPlaylist> _playlists = [];

  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      final list = jsonDecode(data) as List;
      _playlists = list
          .map((e) => LocalPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }

  Future<LocalPlaylist> create(String name) async {
    final playlist = LocalPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      tracks: [],
    );
    _playlists.add(playlist);
    await _save();
    notifyListeners();
    return playlist;
  }

  Future<void> delete(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _playlists[idx].name = name;
    await _save();
    notifyListeners();
  }

  Future<void> addTrack(String playlistId, VideoModel track) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.tracks.any((t) => t.id == track.id)) {
      playlist.tracks.add(track);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.tracks.removeWhere((t) => t.id == trackId);
    await _save();
    notifyListeners();
  }

  /// Returns a playlist by name, creating it if it doesn't exist yet.
  Future<LocalPlaylist> getOrCreate(String name) async {
    LocalPlaylist? existing;
    try {
      existing = _playlists.firstWhere((p) => p.name == name);
    } catch (_) {}
    return existing ?? await create(name);
  }

  /// Returns the "Downloads Automáticos" playlist, creating it if it doesn't exist yet.
  Future<LocalPlaylist> getOrCreateAutoDownloads() async {
    return getOrCreate('Downloads Automáticos');
  }

  Future<void> addTracks(String playlistId, List<VideoModel> tracks) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    var added = false;
    for (final track in tracks) {
      if (!playlist.tracks.any((t) => t.id == track.id)) {
        playlist.tracks.add(track);
        added = true;
      }
    }
    if (added) {
      await _save();
      notifyListeners();
    }
  }
}
