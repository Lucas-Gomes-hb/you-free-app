import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../models/video_model.dart';
import '../models/collection_model.dart';

class ApiService {
  late Dio _dio;

  ApiService(String baseUrl) {
    _rebuildDio(baseUrl);
  }

  void _rebuildDio(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConstants.connectionTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
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

  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'}) async {
    try {
      final response = await _dio.post(
        ApiConstants.streamEndpoint,
        data: {'video_id': videoId, 'format': format},
      );
      if (response.statusCode == 200) return StreamInfo.fromJson(response.data);
      throw Exception('Failed to get stream info');
    } catch (e) {
      throw Exception('Failed to get stream: $e');
    }
  }

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

  Future<CollectionModel> getPlaylist(String url) async {
    try {
      final response = await _dio.post(ApiConstants.playlistEndpoint, data: {'url': url});
      if (response.statusCode == 200) return CollectionModel.fromJson(response.data);
      throw Exception('Falha ao carregar playlist');
    } catch (e) {
      throw Exception('Falha ao carregar playlist: $e');
    }
  }

  Future<CollectionModel> getChannel(String url) async {
    try {
      final response = await _dio.post(ApiConstants.channelEndpoint, data: {'url': url});
      if (response.statusCode == 200) return CollectionModel.fromJson(response.data);
      throw Exception('Falha ao carregar canal');
    } catch (e) {
      throw Exception('Falha ao carregar canal: $e');
    }
  }

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

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _dio.get(ApiConstants.statusEndpoint);
      if (response.statusCode == 200) return Map<String, dynamic>.from(response.data as Map);
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> uploadCookies(String content) async {
    try {
      final response = await _dio.post(ApiConstants.cookiesEndpoint, data: {'content': content});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCookies() async {
    try {
      final response = await _dio.delete(ApiConstants.cookiesEndpoint);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> prefetch(List<String> videoIds) async {
    try {
      await _dio.post('/prefetch', data: {'video_ids': videoIds});
    } catch (_) {}
  }

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
