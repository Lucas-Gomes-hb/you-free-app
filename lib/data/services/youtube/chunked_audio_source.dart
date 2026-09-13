import 'package:just_audio/just_audio.dart';

import 'chunked_stream.dart';

/// A just_audio source backed by [ChunkedStream].
///
/// Replaces `LockCachingAudioSource` for locally-resolved streams: the caching
/// source fetches the whole file in one open-ended request, which these URLs
/// reject.
class ChunkedAudioSource extends StreamAudioSource {
  final String url;
  final int sourceLength;
  final String contentType;

  final ChunkedStream _reader;

  ChunkedAudioSource({
    required this.url,
    required this.sourceLength,
    required this.contentType,
    ChunkedStream? reader,
  })  : _reader = reader ?? ChunkedStream(),
        super(tag: url);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final toExclusive = end ?? sourceLength;

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: toExclusive - from,
      offset: from,
      stream: _reader.read(url, from, toExclusive),
      contentType: contentType,
    );
  }
}
