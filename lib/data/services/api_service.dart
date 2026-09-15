import '../models/video_model.dart';
import '../models/collection_model.dart';
import 'content_source.dart';
import 'local_content_source.dart';
import 'remote_content_source.dart';
import 'youtube/youtube_js_engine.dart';

/// Where the app gets its catalog from.
enum ContentMode {
  /// The YouFree API server (FastAPI + yt-dlp) resolves everything.
  api,

  /// The app resolves everything on-device, no server needed.
  local,
}

/// Single entry point the rest of the app talks to.
///
/// It forwards every call to whichever [ContentSource] the user picked in
/// Settings, so switching modes never invalidates the object graph built in
/// `main.dart`.
class ApiService implements ContentSource {
  final RemoteContentSource _remote;
  final LocalContentSource _local;

  ContentMode _mode;

  ApiService(String baseUrl, {ContentMode mode = ContentMode.local})
      : _remote = RemoteContentSource(baseUrl),
        _local = LocalContentSource(jsEngine: YoutubeJsEngine()),
        _mode = mode;

  ContentMode get mode => _mode;

  bool get isLocal => _mode == ContentMode.local;

  set mode(ContentMode value) => _mode = value;

  ContentSource get _source => isLocal ? _local : _remote;

  void updateBaseUrl(String baseUrl) => _remote.updateBaseUrl(baseUrl);

  static Future<bool> checkConnection(String url) =>
      RemoteContentSource.checkConnection(url);

  @override
  Future<List<VideoModel>> search(String query, {int offset = 0}) =>
      _source.search(query, offset: offset);

  @override
  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'}) =>
      _source.getStreamInfo(videoId, format: format);

  @override
  Future<List<VideoModel>> getSuggestions(
    String videoId, {
    String title = '',
    String uploader = '',
  }) =>
      _source.getSuggestions(videoId, title: title, uploader: uploader);

  @override
  Future<CollectionModel> getPlaylist(String url) => _source.getPlaylist(url);

  @override
  Future<CollectionModel> getChannel(String url) => _source.getChannel(url);

  @override
  Future<List<ChannelInfo>> searchChannels(String query) =>
      _source.searchChannels(query);

  @override
  Future<List<PlaylistPreview>> searchPlaylists(String query) =>
      _source.searchPlaylists(query);

  @override
  Future<List<VideoModel>> getHomeFeed() => _source.getHomeFeed();

  @override
  Future<List<VideoModel>> getGenre(String hashtag) => _source.getGenre(hashtag);

  @override
  Future<List<String>> getSearchSuggestions(String query) =>
      _source.getSearchSuggestions(query);

  @override
  Future<Map<String, dynamic>> getLyrics(String title, String artist) =>
      _source.getLyrics(title, artist);

  @override
  Future<Map<String, dynamic>> getStatus() => _source.getStatus();

  @override
  Future<bool> uploadCookies(String content) => _source.uploadCookies(content);

  @override
  Future<bool> deleteCookies() => _source.deleteCookies();

  @override
  Future<void> prefetch(List<String> videoIds) => _source.prefetch(videoIds);
}
