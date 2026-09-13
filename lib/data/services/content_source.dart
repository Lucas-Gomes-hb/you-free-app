import '../models/video_model.dart';
import '../models/collection_model.dart';

/// Contract shared by every content backend.
///
/// [RemoteContentSource] talks to the YouFree API server; [LocalContentSource]
/// resolves everything on-device. [ApiService] picks one at runtime.
abstract class ContentSource {
  Future<List<VideoModel>> search(String query, {int offset = 0});

  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'});

  Future<List<VideoModel>> getSuggestions(
    String videoId, {
    String title = '',
    String uploader = '',
  });

  Future<CollectionModel> getPlaylist(String url);

  Future<CollectionModel> getChannel(String url);

  Future<List<ChannelInfo>> searchChannels(String query);

  Future<List<PlaylistPreview>> searchPlaylists(String query);

  Future<List<VideoModel>> getHomeFeed();

  Future<List<VideoModel>> getGenre(String hashtag);

  Future<List<String>> getSearchSuggestions(String query);

  Future<Map<String, dynamic>> getLyrics(String title, String artist);

  Future<Map<String, dynamic>> getStatus();

  Future<bool> uploadCookies(String content);

  Future<bool> deleteCookies();

  Future<void> prefetch(List<String> videoIds);
}
