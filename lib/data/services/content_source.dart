import '../models/collection_model.dart';
import '../models/comment_model.dart';
import '../models/search_filter_option.dart';
import '../models/video_model.dart';

/// Everything the app can ask a content source for.
///
/// Two implementations answer it: [RemoteContentSource], which talks to the
/// YouTube API, and [LocalContentSource], which answers from files on the
/// device through InnerTube's JS runtime. The app only ever holds a
/// `ContentSource`, so a screen never has to know which one it is talking to.
abstract class ContentSource {
  Future<List<VideoModel>> search(String query, {int offset = 0});

  /// The playable source for a video.
  ///
  /// [format] is `audio` or `video`; a video resolve is the expensive one, so
  /// the player only asks for it when a video is actually about to play.
  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'});

  /// "Up next" for a video. [title] and [uploader] sharpen the query when the
  /// source has to fall back to a text search.
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

  /// Warms the resolve of videos the user is likely to open next.
  Future<void> prefetch(List<String> videoIds);

  Future<VideoDetails> getVideoDetails(String videoId);

  Future<List<VideoModel>> getRelated(String videoId);

  /// One page of comments. [continuation] pages forward; [sort] picks the
  /// ordering the section's own sort menu offers.
  Future<CommentPage> getComments(
    String videoId, {
    String? continuation,
    CommentSort sort = CommentSort.top,
  });

  /// Results with a refinement applied, the second half of the filter bar.
  Future<List<VideoModel>> searchVideos(String query, {String? params});

  /// Chips the user can refine by. The values are opaque, and only valid in the
  /// context they were listed in, so they are re-listed rather than cached
  /// across searches.
  Future<List<SearchFilterOption>> getSearchFilters(
    String query, {
    String? params,
  });
}

/// Ordering offered on the comment section.
enum CommentSort {
  top,
  newest;

  String get label => switch (this) {
        CommentSort.top => 'Principais',
        CommentSort.newest => 'Recentes',
      };
}