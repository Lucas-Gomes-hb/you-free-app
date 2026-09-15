import 'dart:async';

import 'package:dio/dio.dart';

/// Raised when a range cannot be read after exhausting the retries.
class ChunkedStreamException implements Exception {
  final String message;
  ChunkedStreamException(this.message);
  @override
  String toString() => message;
}

/// Fetches a YouTube CDN stream in bounded byte ranges.
///
/// Tokenless CDN URLs answer 403 to open-ended and header-less requests — the
/// shape every off-the-shelf player and downloader uses — but serve bounded
/// ranges (`bytes=a-b`) happily. Reading in fixed chunks is what keeps those
/// streams playable and downloadable without a proof-of-origin token.
class ChunkedStream {
  static const defaultChunkSize = 512 * 1024;
  static const defaultMaxRetries = 4;

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
    int maxRetries = defaultMaxRetries,
  }) async* {
    var position = start;
    var failures = 0;
    while (position < endExclusive) {
      final last = (position + chunkSize - 1).clamp(0, endExclusive - 1);
      final wanted = last - position + 1;
      // The CDN can end a response early — the bytes that arrived are good, the
      // rest simply never came. Only what was counted may advance [position];
      // trusting the requested range instead leaves a silent gap in the audio
      // and the player waits forever for bytes that are never fetched.
      var received = 0;
      try {
        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Range': 'bytes=$position-$last'},
            validateStatus: (status) => status != null && status < 400,
          ),
          cancelToken: cancelToken,
        );
        // A 200 ignores the range and restarts at byte 0, so it only lines up
        // when that is where this chunk begins.
        if (response.statusCode == 206 || (response.statusCode == 200 && position == 0)) {
          await for (final chunk in response.data!.stream) {
            if (received >= wanted) break;
            final remaining = wanted - received;
            final take = chunk.length <= remaining ? chunk : chunk.sublist(0, remaining);
            received += take.length;
            yield take;
          }
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        // Anything else is retried below from wherever the bytes stopped.
      }

      position += received;
      // A short chunk still made progress — the next pass just asks for the
      // remainder — so the retry budget only burns on attempts that delivered
      // nothing at all.
      if (received > 0) {
        failures = 0;
        continue;
      }
      if (++failures > maxRetries) {
        throw ChunkedStreamException(
          'Leitura interrompida em $position de $endExclusive bytes '
          'apos $maxRetries tentativas sem resposta.',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * failures));
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
