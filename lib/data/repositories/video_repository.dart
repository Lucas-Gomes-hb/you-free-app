import '../models/video_model.dart';
import '../models/collection_model.dart';
import '../services/api_service.dart';

class VideoRepository {
  final ApiService _apiService;

  VideoRepository(this._apiService);

  Future<List<VideoModel>> searchVideos(String query, {int offset = 0}) async {
    return await _apiService.search(query, offset: offset);
  }

  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'}) async {
    return await _apiService.getStreamInfo(videoId, format: format);
  }


  Future<List<VideoModel>> getSuggestions(
    String videoId, {
    String title = '',
    String uploader = '',
  }) async {
    return await _apiService.getSuggestions(videoId, title: title, uploader: uploader);
  }

  Future<CollectionModel> getCollection(String url) async {
    final isChannel = url.startsWith('@') ||
        url.contains('/channel/') ||
        url.contains('/@') ||
        RegExp(r'youtube\.com/c/').hasMatch(url);
    if (isChannel) {
      return await _apiService.getChannel(url);
    }
    return await _apiService.getPlaylist(url);
  }

  Future<List<ChannelInfo>> searchChannels(String query) async {
    return await _apiService.searchChannels(query);
  }

  Future<List<PlaylistPreview>> searchPlaylists(String query) async {
    return await _apiService.searchPlaylists(query);
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    return await _apiService.getSearchSuggestions(query);
  }

  void warmServerCache(List<String> videoIds) {
    if (videoIds.isEmpty) return;
    _apiService.prefetch(videoIds);
  }

  Future<List<VideoModel>> getHomeFeed() async {
    return await _apiService.getHomeFeed();
  }

  Future<Map<String, dynamic>> getLyrics(String title, String artist) async {
    return await _apiService.getLyrics(title, artist);
  }
}
