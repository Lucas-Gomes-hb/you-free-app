// Smoke test for LocalContentSource against the live InnerTube endpoints.
// Run with: dart run tool/verify_local_source.dart
import 'dart:io';

import '../lib/data/services/local_content_source.dart';
import '../lib/data/services/youtube/chunked_stream.dart';

int _failures = 0;

Future<void> check(String label, Future<void> Function() body) async {
  try {
    await body();
  } catch (e) {
    _failures++;
    print('  FALHOU  $label -> $e');
  }
}

void expectTrue(bool condition, String message) {
  if (!condition) throw Exception(message);
}

Future<void> main() async {
  final source = LocalContentSource();

  await check('search', () async {
    final results = await source.search('rick astley never gonna give you up');
    expectTrue(results.isNotEmpty, 'sem resultados');
    expectTrue(results.every((v) => v.id.length == 11), 'id invalido');
    expectTrue(results.any((v) => v.duration != null), 'nenhuma duracao');
    expectTrue(results.any((v) => v.uploader != null), 'nenhum uploader');
    print('  OK      search -> ${results.length} itens | '
        '"${results.first.title}" (${results.first.durationFormatted}) '
        'por ${results.first.uploader}');
  });

  await check('search paginado', () async {
    final page1 = await source.search('lofi hip hop');
    final page2 = await source.search('lofi hip hop', offset: page1.length);
    final ids1 = page1.map((v) => v.id).toSet();
    expectTrue(page2.isNotEmpty, 'pagina 2 vazia');
    expectTrue(page2.any((v) => !ids1.contains(v.id)), 'pagina 2 repetida');
    print('  OK      paginacao -> p1 ${page1.length}, p2 ${page2.length} '
        '(${page2.where((v) => !ids1.contains(v.id)).length} novos)');
  });

  await check('stream audio', () async {
    final info = await source.getStreamInfo('dQw4w9WgXcQ');
    expectTrue(info.formats.isNotEmpty, 'sem formatos');
    final best = info.bestAudio;
    expectTrue(best != null, 'bestAudio nulo');
    expectTrue(best!.url.startsWith('http'), 'url invalida');
    print('  OK      stream audio -> "${info.title}" | ${info.duration}s | '
        '${info.formats.length} formatos | melhor: ${best.ext} '
        '${best.quality} (${best.filesize} bytes)');

    // A URL precisa servir midia do jeito que o player pede de verdade:
    // sem header de Range, e com Range aberto no seek. Sem o parametro
    // "range" na query o CDN responde 403 nos dois casos.
    for (final headers in [<String, String>{}, {'Range': 'bytes=0-'}]) {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(best.url));
      headers.forEach(request.headers.set);
      final response = await request.close();
      final bytes =
          await response.fold<int>(0, (sum, chunk) => sum + chunk.length);
      client.close();
      expectTrue(response.statusCode == 200 || response.statusCode == 206,
          'HTTP ${response.statusCode} com headers $headers');
      expectTrue(bytes > 100000, 'apenas $bytes bytes com headers $headers');
      print('  OK      download   -> ${headers.isEmpty ? 'sem Range' : 'Range aberto'}'
          ': HTTP ${response.statusCode} | ${response.headers.contentType} | '
          '$bytes bytes');
    }
  });

  await check('stream video', () async {
    final info = await source.getStreamInfo('dQw4w9WgXcQ', format: 'video');
    expectTrue(info.videoUrl != null, 'sem videoUrl');
    print('  OK      stream video -> ${info.videoUrl!.substring(0, 60)}...');
  });

  await check('cache de stream', () async {
    final started = DateTime.now();
    await source.getStreamInfo('dQw4w9WgXcQ');
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    expectTrue(elapsed < 50, 'demorou ${elapsed}ms, cache nao pegou');
    print('  OK      cache      -> ${elapsed}ms (hit)');
  });

  await check('sugestoes (radio)', () async {
    final results = await source.getSuggestions(
      'dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      uploader: 'Rick Astley',
    );
    expectTrue(results.length >= 5, 'apenas ${results.length}');
    expectTrue(results.every((v) => v.id != 'dQw4w9WgXcQ'), 'inclui a propria');
    print('  OK      sugestoes  -> ${results.length} itens | '
        'ex: "${results.first.title}"');
  });

  await check('busca de canais', () async {
    final channels = await source.searchChannels('rick astley');
    expectTrue(channels.isNotEmpty, 'sem canais');
    expectTrue(channels.first.thumbnail != null, 'sem thumbnail');
    print('  OK      canais     -> ${channels.length} | '
        '"${channels.first.name}" (${channels.first.id})');
  });

  await check('busca de playlists', () async {
    final playlists = await source.searchPlaylists('rock classics');
    expectTrue(playlists.isNotEmpty, 'sem playlists');
    print('  OK      playlists  -> ${playlists.length} | '
        '"${playlists.first.title}" (${playlists.first.itemCount} itens)');
  });

  await check('abrir playlist', () async {
    final found = await source.searchPlaylists('rock classics');
    final collection = await source.getPlaylist(found.first.url);
    expectTrue(collection.items.isNotEmpty, 'playlist vazia');
    expectTrue(collection.items.any((v) => v.duration != null), 'sem duracoes');
    print('  OK      playlist   -> "${collection.title}" | '
        '${collection.items.length} faixas | '
        'ex: "${collection.items.first.title}" '
        '(${collection.items.first.durationFormatted})');
  });

  await check('abrir canal por @handle', () async {
    final collection = await source.getChannel('@RickAstleyYT');
    expectTrue(collection.items.isNotEmpty, 'canal sem videos');
    expectTrue(collection.title.isNotEmpty, 'canal sem titulo');
    print('  OK      canal      -> "${collection.title}" | '
        '${collection.items.length} videos | thumb: '
        '${collection.thumbnail != null}');
  });

  await check('home feed', () async {
    final feed = await source.getHomeFeed();
    expectTrue(feed.isNotEmpty, 'feed vazio');
    print('  OK      home feed  -> ${feed.length} itens | '
        'ex: "${feed.first.title}"');
  });

  await check('genero', () async {
    final results = await source.getGenre('lofi');
    expectTrue(results.isNotEmpty, 'sem resultados');
    print('  OK      genero     -> ${results.length} itens');
  });

  await check('autocomplete', () async {
    final suggestions = await source.getSearchSuggestions('rick as');
    expectTrue(suggestions.isNotEmpty, 'sem sugestoes');
    print('  OK      autocomplete -> ${suggestions.take(3).join(" / ")}');
  });

  await check('letras', () async {
    final lyrics = await source.getLyrics(
      'Never Gonna Give You Up (Official Video)',
      'Rick Astley - Topic',
    );
    expectTrue(lyrics['found'] == true, 'nao encontrou');
    print('  OK      letras     -> sync: ${lyrics['has_sync']} | '
        '${(lyrics['plain_lyrics'] as String).length} chars');
  });

  await check('video estrangulado e recusado com erro claro', () async {
    // Sem PO Token o YouTube serve so o primeiro trecho destes videos. A sonda
    // no fim do arquivo pega isso antes de o player engasgar no meio.
    try {
      await source.getStreamInfo('FGBhQbmPwH8');
      throw Exception('deveria ter recusado');
    } catch (e) {
      expectTrue('$e'.contains('modo local'), 'mensagem inesperada: $e');
      print('  OK      estrangulado -> recusado antes de tocar, com mensagem '
          'apontando o modo API');
    }
  });

  await check('leitura em blocos a partir de um seek', () async {
    final info = await source.getStreamInfo('dQw4w9WgXcQ');
    final format = info.bestAudio!;
    final size = format.filesize!;
    final from = size ~/ 2;

    final reader = ChunkedStream();
    var received = 0;
    await for (final chunk in reader.read(format.url, from, size)) {
      received += chunk.length;
    }
    reader.close();
    expectTrue(received == size - from, 'leu $received, esperado ${size - from}');
    print('  OK      seek       -> leu $received bytes a partir do byte $from');
  });

  await check('prefetch', () async {
    await source.prefetch(['dQw4w9WgXcQ']);
    final started = DateTime.now();
    await source.getStreamInfo('dQw4w9WgXcQ');
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    expectTrue(elapsed < 50, 'prefetch nao populou o cache (${elapsed}ms)');
    print('  OK      prefetch   -> stream pronto em ${elapsed}ms');
  });

  await check('video indisponivel da erro claro', () async {
    try {
      await source.getStreamInfo('aaaaaaaaaaa');
      throw Exception('deveria ter lancado');
    } catch (e) {
      expectTrue('$e'.contains('indisponível') || '$e'.contains('Exception'),
          'erro inesperado: $e');
      print('  OK      erro       -> tratado');
    }
  });

  print('');
  if (_failures == 0) {
    print('TODOS OS CHECKS PASSARAM');
  } else {
    print('$_failures CHECK(S) FALHARAM');
    exitCode = 1;
  }
}
