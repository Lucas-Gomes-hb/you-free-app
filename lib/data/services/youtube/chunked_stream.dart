import 'dart:async';

import 'package:dio/dio.dart';

/// Fetches a YouTube CDN stream in bounded byte ranges.
///
/// Tokenless CDN URLs answer 403 to open-ended and header-less requests — the
/// shape every off-the-shelf player and downloader uses — but serve bounded
/// ranges (`bytes=a-b`) happily. Reading in fixed chunks is what keeps those
/// streams playable and downloadable without a proof-of-origin token.
class ChunkedStream {
  static const defaultChunkSize = 512 * 1024;

  final Dio _dio;

  ChunkedStream({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// Emits `[start, endExclusive)` of [url], one bounded request per chunk.
  Stream<List<int>> read(
    String url,
    int start,
    int endExclusive, {
    int chunkSize = defaultChunkSize,
    CancelToken? cancelToken,
  }) async* {
    var position = start;
    while (position < endExclusive) {
      final last = (position + chunkSize - 1).clamp(0, endExclusive - 1);
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=$position-$last'},
        ),
        cancelToken: cancelToken,
      );
      await for (final chunk in response.data!.stream) {
        yield chunk;
      }
      position = last + 1;
    }
  }

  /// Total size of [url], read from the `Content-Range` of a 2-byte probe.
  /// Returns null when the CDN refuses the URL altogether.
  Future<int?> length(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-1'},
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );
      if (response.statusCode != 206 && response.statusCode != 200) return null;
      final contentRange =
          response.headers.value('content-range') ?? response.headers.value('Content-Range');
      final total = contentRange?.split('/').last;
      return total == null ? null : int.tryParse(total);
    } catch (_) {
      return null;
    }
  }

  void close() => _dio.close(force: true);
}
