import 'package:dio/dio.dart';

class LyricsResult {
  final String? plainLyrics;
  final String? syncedLyrics;
  final bool hasSync;
  final bool found;

  const LyricsResult({
    this.plainLyrics,
    this.syncedLyrics,
    this.hasSync = false,
    this.found = false,
  });

  static const empty = LyricsResult();
}

class LyricsService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static String _clean(String title) {
    var t = title;
    t = t.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*'
        r'(prod\.?|ft\.?|feat\.?|official|video|audio|lyric|clipe|mv|hq|4k|hd|remaster|tradução|legendado|live)[^\)\]]*[\)\]]\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    t = t.replaceAll(RegExp(r'\s*ft\.?\s+.*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*feat\.?\s+.*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '');
    t = t.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static (String title, String artist) _split(String rawTitle, String rawArtist) {
    final clean = _clean(rawTitle);
    final artist = rawArtist
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();
    if (clean.contains(' - ')) {
      final idx = clean.indexOf(' - ');
      return (clean.substring(idx + 3).trim(), clean.substring(0, idx).trim());
    }
    return (clean, artist);
  }

  static Future<LyricsResult> fetch(String rawTitle, String rawArtist) async {
    final (title, artist) = _split(rawTitle, rawArtist);

    // 1. LRCLib — synced + plain
    try {
      final resp = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {'track_name': title, 'artist_name': artist},
        options: Options(headers: {'Lrclib-Client': 'YouFree/1.0'}),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final synced = ((resp.data['syncedLyrics'] as String?) ?? '').trim();
        final plain = ((resp.data['plainLyrics'] as String?) ?? '').trim();
        if (synced.isNotEmpty || plain.isNotEmpty) {
          return LyricsResult(
            plainLyrics: plain.isEmpty ? null : plain,
            syncedLyrics: synced.isEmpty ? null : synced,
            hasSync: synced.isNotEmpty,
            found: true,
          );
        }
      }
    } catch (_) {}

    // 2. lyrics.ovh — plain only fallback
    try {
      final encArtist = Uri.encodeComponent(artist);
      final encTitle = Uri.encodeComponent(title);
      final resp = await _dio.get('https://api.lyrics.ovh/v1/$encArtist/$encTitle');
      if (resp.statusCode == 200 && resp.data is Map) {
        final plain = ((resp.data['lyrics'] as String?) ?? '').trim();
        if (plain.isNotEmpty) {
          return LyricsResult(plainLyrics: plain, found: true);
        }
      }
    } catch (_) {}

    return LyricsResult.empty;
  }
}
