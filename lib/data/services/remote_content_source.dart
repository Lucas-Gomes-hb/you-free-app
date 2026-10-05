import 'package:dio/dio.dart';
import '../../app/app_mode.dart';
import '../../core/constants.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';
import '../models/collection_model.dart';
import 'content_source.dart';
import '../models/search_filter_option.dart';

/// Talks to a running YouFree API server (FastAPI + yt-dlp).
class RemoteContentSource implements ContentSource {
  late Dio _dio;

  /// Sent as X-YouFree-Mode so the server can relax its music-only filter in
  /// video mode — otherwise long videos never leave the server.
  AppMode _appMode = AppMode.music;

  AppMode get appMode => _appMode;

  set appMode(AppMode value) {
    if (_appMode == value) return;
    _appMode = value;
    _dio.options.headers['X-YouFree-Mode'] = value.name;
  }

  RemoteContentSource(String baseUrl) {
    _rebuildDio(baseUrl);
  }

  String _baseUrl = '';

  void _rebuildDio(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConstants.connectionTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'X-YouFree-Mode': _appMode.name,
      },
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ));
  }

  void updateBaseUrl(String baseUrl) => _rebuildDio(baseUrl);

  static Future<bool> checkConnection(String url) async {
    final dio = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    try {
      final response = await dio.get(ApiConstants.statusEndpoint);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      dio.close();
    }
  }

  @override
  Future<List<VideoModel>> search(String query, {int offset = 0}) async {
    try {
      final response = await _dio.post(
        ApiConstants.searchEndpoint,
        data: {'query': query, 'offset': offset},
      );
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => VideoModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to search: $e');
    }
  }

  @override
  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'}) async {
    try {
      final response = await _dio.post(
        ApiConstants.streamEndpoint,
        data: {'video_id': videoId, 'format': format},
      );
      if (response.statusCode == 200) {
        return withAbsoluteStreamUrl(
            _baseUrl, StreamInfo.fromJson(response.data));
      }
      throw Exception('Failed to get stream info');
    } catch (e) {
      throw Exception('Failed to get stream: $e');
    }
  }

  @override
  Future<List<VideoModel>> getSuggestions(
    String videoId, {
    String title = '',
    String uploader = '',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.suggestionsEndpoint,
        data: {'video_id': videoId, 'title': title, 'uploader': uploader},
      );
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<CollectionModel> getPlaylist(String url) async {
    try {
      final response = await _dio.post(ApiConstants.playlistEndpoint, data: {'url': url});
      if (response.statusCode == 200) return CollectionModel.fromJson(response.data);
      throw Exception('Falha ao carregar playlist');
    } catch (e) {
      throw Exception('Falha ao carregar playlist: $e');
    }
  }

  @override
  Future<CollectionModel> getChannel(String url) async {
    try {
      final response = await _dio.post(ApiConstants.channelEndpoint, data: {'url': url});
      if (response.statusCode == 200) return CollectionModel.fromJson(response.data);
      throw Exception('Falha ao carregar canal');
    } catch (e) {
      throw Exception('Falha ao carregar canal: $e');
    }
  }

  @override
  Future<List<ChannelInfo>> searchChannels(String query) async {
    try {
      final response = await _dio.post(ApiConstants.searchChannelsEndpoint, data: {'query': query});
      if (response.statusCode == 200) {
        final results = response.data['channels'] as List;
        return results.map((e) => ChannelInfo.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PlaylistPreview>> searchPlaylists(String query) async {
    try {
      final response = await _dio.post(ApiConstants.searchPlaylistsEndpoint, data: {'query': query});
      if (response.statusCode == 200) {
        final results = response.data['playlists'] as List;
        return results.map((e) => PlaylistPreview.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<VideoModel>> getHomeFeed() async {
    try {
      final response = await _dio.get(ApiConstants.homeFeedEndpoint);
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Video mode ───────────────────────────────────────────────────────────

  @override
  Future<VideoDetails> getVideoDetails(String videoId) async {
    final response = await _dio.post(
      ApiConstants.videoDetailsEndpoint,
      data: {'video_id': videoId},
    );
    if (response.statusCode != 200) {
      throw StateError('Falha ao carregar os detalhes do vídeo');
    }
    return VideoDetails.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<List<VideoModel>> getRelated(String videoId) async {
    final response = await _dio.post(
      ApiConstants.relatedEndpoint,
      data: {'video_id': videoId},
    );
    if (response.statusCode != 200) return const [];
    final results = (response.data['results'] as List?) ?? const [];
    return results
        .map((e) => VideoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<CommentPage> getComments(
    String videoId, {
    String? continuation,
    CommentSort sort = CommentSort.top,
  }) async {
    final response = await _dio.post(
      ApiConstants.commentsEndpoint,
      data: {
        'video_id': videoId,
        if (continuation != null) 'continuation': continuation,
        'sort': sort.name,
      },
    );
    if (response.statusCode != 200) return const CommentPage(comments: []);
    return CommentPage.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<List<VideoModel>> searchVideos(String query, {String? params}) async {
    final response = await _dio.post(
      ApiConstants.searchVideosEndpoint,
      data: {
        'query': query,
        if (params != null && params.isNotEmpty) 'params': params,
      },
    );
    if (response.statusCode != 200) return const [];
    final results = (response.data['results'] as List?) ?? const [];
    return results
        .map((e) => VideoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<SearchFilterOption>> getSearchFilters(
    String query, {
    String? params,
  }) async {
    final response = await _dio.post(
      ApiConstants.searchFiltersEndpoint,
      data: {
        'query': query,
        if (params != null && params.isNotEmpty) 'params': params,
      },
    );
    if (response.statusCode != 200) return const [];
    final options = (response.data['filters'] as List?) ?? const [];
    return options
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((e) => SearchFilterOption(
              value: e['value'] as String? ?? '',
              label: e['label'] as String? ?? '',
              iconHint: e['icon'] as String?,
            ))
        .where((o) => o.value.isNotEmpty)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _dio.get(ApiConstants.statusEndpoint);
      if (response.statusCode == 200) return Map<String, dynamic>.from(response.data as Map);
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> uploadCookies(String content) async {
    try {
      final response = await _dio.post(ApiConstants.cookiesEndpoint, data: {'content': content});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> deleteCookies() async {
    try {
      final response = await _dio.delete(ApiConstants.cookiesEndpoint);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> prefetch(List<String> videoIds) async {
    try {
      await _dio.post('/prefetch', data: {'video_ids': videoIds});
    } catch (_) {}
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final response = await _dio.get(
        '/suggest',
        queryParameters: {'q': query},
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (response.statusCode == 200) {
        return List<String>.from(response.data['suggestions'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getLyrics(String title, String artist) async {
    try {
      final response = await _dio.get(
        ApiConstants.lyricsEndpoint,
        queryParameters: {'title': title, 'artist': artist},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      if (response.statusCode == 200) return Map<String, dynamic>.from(response.data as Map);
      return {'found': false};
    } catch (_) {
      return {'found': false};
    }
  }

  @override
  Future<List<VideoModel>> getGenre(String hashtag) async {
    try {
      final response = await _dio.get('${ApiConstants.genreEndpoint}/$hashtag');
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

/// Turns the API's root-relative `video_url` and `hls_url` into absolute ones.
///
/// DASH has to be addressed by URL: the player fetches the MPD and then the
/// segment ranges itself, so the manifest cannot be inlined in the JSON body.
/// The API only knows its own path, never the host the device reached it on —
/// `adb reverse` and a LAN address are both in play — so the join happens here,
/// where the base URL is known.
///
/// A URL that is already absolute is returned untouched: progressive sources
/// point straight at googlevideo.
StreamInfo withAbsoluteStreamUrl(String baseUrl, StreamInfo info) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  String? absolute(String? url) {
    if (url == null || !url.startsWith('/')) return url;
    return '$base$url';
  }

  final videoUrl = absolute(info.videoUrl);
  final hlsUrl = absolute(info.hlsUrl);
  if (videoUrl == info.videoUrl && hlsUrl == info.hlsUrl) return info;

  return StreamInfo(
    title: info.title,
    thumbnail: info.thumbnail,
    duration: info.duration,
    uploader: info.uploader,
    formats: info.formats,
    videoUrl: videoUrl,
    videoFormat: info.videoFormat,
    videoResolutions: info.videoResolutions,
    // Both manifests come from the same endpoint and need the same join, so
    // leaving this null here would quietly send the player back to DASH.
    hlsUrl: hlsUrl,
  );
}
