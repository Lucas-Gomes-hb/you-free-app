import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/video_model.dart';
import '../models/collection_model.dart';
import 'content_source.dart';
import 'lyrics_service.dart';
import 'youtube/innertube_client.dart';
import 'youtube/innertube_parser.dart';

/// On-device replacement for the YouFree API server.
///
/// Talks straight to YouTube's InnerTube endpoints, so the app plays with no
/// backend running. Caching and the music-only filtering that used to live in
/// the server were moved here so both modes behave the same.
class LocalContentSource implements ContentSource {
  // Search filter params, base64 protobuf, same values the web client sends.
  static const _filterChannels = 'EgIQAg%3D%3D';
  static const _filterPlaylists = 'EgIQAw%3D%3D';
  // Channel "Videos" tab.
  static const _tabVideos = 'EgZ2aWRlb3PyBgQKAjoA';

  static const _streamTtl = Duration(hours: 4);
  static const _feedTtl = Duration(hours: 2);
  static const _maxStreamCacheEntries = 500;
  static const _maxConcurrentPrefetch = 4;

  static const _nonMusicKeywords = [
    'podcast', 'interview', 'entrevista', 'full movie', 'filme completo',
    'trailer', 'episode', 'episódio', 'talk show', 'documentary',
    'documentário', 'reaction', 'reação', 'unboxing', 'gameplay',
    'tutorial', 'review', 'análise', 'vlog',
  ];

  static const _genericChannelWords = [
    'music', 'lyrics', 'vevo', 'official', 'records', 'channel',
    'entertainment', 'media', 'label', 'publishing',
  ];

  final InnertubeClient _tube;
  final Dio _plain;

  final Map<String, _CacheEntry<StreamInfo>> _streamCache = {};
  final Map<String, String> _searchContinuations = {};
  final Map<String, _CacheEntry<List<VideoModel>>> _genreCache = {};
  final Set<String> _prefetching = {};

  _CacheEntry<List<VideoModel>>? _homeFeed;

  LocalContentSource({InnertubeClient? client})
      : _tube = client ?? InnertubeClient(),
        _plain = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ));

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  Future<List<VideoModel>> search(String query, {int offset = 0}) async {
    final key = query.trim().toLowerCase();
    Map<String, dynamic> response;

    if (offset == 0) {
      response = await _tube.call('search', {'query': query});
    } else {
      final token = _searchContinuations[key];
      if (token == null) return [];
      response = await _tube.call('search', {'continuation': token});
    }

    final next = InnertubeParser.continuationToken(response);
    if (next != null) {
      _searchContinuations[key] = next;
    } else {
      _searchContinuations.remove(key);
    }

    final videos = InnertubeParser.videosFrom(
      response['contents'] ?? response['onResponseReceivedCommands'],
      limit: 20,
    );
    if (offset == 0 && videos.isNotEmpty) {
      unawaited(prefetch(videos.take(5).map((v) => v.id).toList()));
    }
    return videos;
  }

  @override
  Future<List<ChannelInfo>> searchChannels(String query) async {
    final response = await _tube.call('search', {
      'query': query,
      'params': _filterChannels,
    });

    final seen = <String>{};
    final channels = <ChannelInfo>[];
    for (final renderer
        in InnertubeParser.findAll(response['contents'], 'channelRenderer')) {
      final channel = InnertubeParser.channelFromRenderer(renderer);
      if (channel == null || !seen.add(channel.id)) continue;
      channels.add(channel);
      if (channels.length >= 6) break;
    }
    return channels;
  }

  @override
  Future<List<PlaylistPreview>> searchPlaylists(String query) async {
    final response = await _tube.call('search', {
      'query': query,
      'params': _filterPlaylists,
    });

    final seen = <String>{};
    final playlists = <PlaylistPreview>[];
    for (final lockup
        in InnertubeParser.findAll(response['contents'], 'lockupViewModel')) {
      final playlist = InnertubeParser.playlistFromLockup(lockup);
      if (playlist == null || !seen.add(playlist.id)) continue;
      playlists.add(playlist);
      if (playlists.length >= 10) break;
    }
    return playlists;
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _plain.get<dynamic>(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'firefox', 'ds': 'yt', 'q': query},
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final decoded = jsonDecode('${response.data}');
      if (decoded is List && decoded.length > 1 && decoded[1] is List) {
        return (decoded[1] as List).whereType<String>().take(8).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Stream resolution ─────────────────────────────────────────────────────

  @override
  Future<StreamInfo> getStreamInfo(String videoId, {String format = 'audio'}) async {
    if (videoId.isEmpty) throw Exception('video_id is required');

    final cacheKey = '$videoId:$format';
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired(_streamTtl)) return cached.value;
    _streamCache.remove(cacheKey);

    // Both identities hand back plain `url` fields; every other client returns
    // `signatureCipher`, which would need a JS engine on-device. ANDROID_VR
    // comes first because it is the only one carrying muxed (video+audio)
    // formats, and IOS covers the videos where ANDROID_VR hits a bot check.
    String? lastReason;
    var loginRequired = false;

    // Second pass runs with a fresh session id, which is what an expired one
    // looks like from here: every client suddenly reports a bot check.
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt == 1) {
        if (!loginRequired) break;
        _tube.resetVisitor();
      }

      for (final client in const [
        InnertubeClient.androidVr,
        InnertubeClient.ios,
        InnertubeClient.android,
      ]) {
        final Map<String, dynamic> response;
        try {
          response = await _tube.call(
            'player',
            {'videoId': videoId, 'contentCheckOk': true, 'racyCheckOk': true},
            client: client,
          );
        } catch (e) {
          lastReason = '$e';
          continue;
        }

        final status = response['playabilityStatus'];
        if (status is Map && status['status'] != 'OK') {
          loginRequired = status['status'] == 'LOGIN_REQUIRED';
          lastReason = '${status['reason'] ?? status['status']}';
          continue;
        }

        final info = _streamInfoFrom(response, videoId, format);
        if (info == null) {
          lastReason = 'sem formato compatível (${client.name})';
          continue;
        }

        // The CDN rejects some videos outright unless the request carries a
        // proof-of-origin token, which needs YouTube's JS challenge. Catching
        // that here lets the next client try, instead of handing the player a
        // URL that dies mid-playback.
        final playable = format == 'video'
            ? await _isPlayable(info.videoUrl!, null)
            : await _isPlayable(
                info.bestAudio!.url, info.bestAudio!.filesize);
        if (!playable) {
          lastReason = 'stream recusado pelo CDN (${client.name})';
          continue;
        }

        _cacheStream(cacheKey, info);
        return info;
      }
    }

    throw Exception(
      'Não foi possível tocar no modo local (${lastReason ?? 'motivo desconhecido'}). '
      'Este vídeo exige autenticação do YouTube — use o modo "pela API".',
    );
  }

  /// Probes the **last** two bytes of the stream.
  ///
  /// Throttled URLs — the ones YouTube serves when no proof-of-origin token
  /// accompanies the request — still hand out the first megabyte or so before
  /// turning to 403, so a probe at the start proves nothing. Asking for the
  /// tail settles in one request whether the whole track is actually
  /// reachable, and lets the next client take over when it is not.
  Future<bool> _isPlayable(String url, int? contentLength) async {
    final start = (contentLength == null || contentLength < 2)
        ? 0
        : contentLength - 2;
    final cancelToken = CancelToken();
    try {
      final response = await _plain.get<ResponseBody>(
        url,
        options: Options(
          headers: {'Range': 'bytes=$start-${start + 1}'},
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );
      return response.statusCode == 206 || response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      cancelToken.cancel();
    }
  }

  /// Builds a [StreamInfo], or null when this response carries nothing the
  /// player can use — which tells the caller to try the next client.
  StreamInfo? _streamInfoFrom(
    Map<String, dynamic> response,
    String videoId,
    String format,
  ) {
    final details = (response['videoDetails'] as Map?) ?? const {};
    final streaming = (response['streamingData'] as Map?) ?? const {};

    final formats = format == 'video'
        ? const <Map<String, dynamic>>[]
        : _audioFormats(streaming['adaptiveFormats']);
    // HLS is the fallback when no muxed progressive stream is offered; both
    // ExoPlayer and AVPlayer read it natively.
    final videoUrl = format == 'video'
        ? (_muxedUrl(streaming['formats']) ??
            streaming['hlsManifestUrl'] as String?)
        : null;

    if (format == 'video' ? videoUrl == null : formats.isEmpty) return null;

    return StreamInfo.fromJson({
      'title': details['title'] ?? '',
      'thumbnail': InnertubeParser.bestThumb(
        InnertubeParser.largestImage(details['thumbnail']),
        videoId,
      ),
      'duration': int.tryParse('${details['lengthSeconds'] ?? ''}'),
      'uploader': details['author'],
      'formats': formats,
      'video_url': videoUrl,
    });
  }

  /// Audio-only tracks, best bitrate first.
  List<Map<String, dynamic>> _audioFormats(dynamic adaptiveFormats) {
    if (adaptiveFormats is! List) return const [];

    final audio = adaptiveFormats
        .whereType<Map>()
        .where((f) =>
            f['url'] is String &&
            '${f['mimeType'] ?? ''}'.startsWith('audio'))
        .toList()
      ..sort((a, b) =>
          ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));

    return audio.map((f) {
      final size = int.tryParse('${f['contentLength'] ?? ''}');
      return <String, dynamic>{
        'format_id': '${f['itag'] ?? ''}',
        // No `range` query param here: audio is read through [ChunkedStream],
        // whose bounded Range headers conflict with a range pinned in the URL.
        'url': f['url'],
        'ext': _extFor('${f['mimeType'] ?? ''}'),
        'quality': f['audioQuality'] ?? '${f['bitrate'] ?? ''}',
        'filesize': size,
        'is_audio_only': true,
      };
    }).toList();
  }

  /// Makes a CDN URL behave like an ordinary progressive file.
  ///
  /// Without an explicit `range`, googlevideo answers 403 to open-ended and
  /// header-less requests. The video player talks to the CDN directly and
  /// cannot be taught to chunk, so its URL gets the full span pinned instead.
  String _progressiveUrl(String url, int? contentLength) {
    if (contentLength == null || contentLength <= 0) return url;
    if (url.contains('&range=') || url.contains('?range=')) return url;
    return '$url&range=0-${contentLength - 1}';
  }

  /// Muxed (video+audio in one file) stream — the only shape the video player
  /// can consume from a single URL. In practice YouTube serves itag 18 / 360p.
  String? _muxedUrl(dynamic formats) {
    if (formats is! List) return null;

    final muxed = formats
        .whereType<Map>()
        .where((f) => f['url'] is String)
        .toList()
      ..sort((a, b) => _height(b).compareTo(_height(a)));
    if (muxed.isEmpty) return null;

    final chosen = muxed.firstWhere(
      (f) => _height(f) <= 720,
      orElse: () => muxed.last,
    );
    return _progressiveUrl(
      chosen['url'] as String,
      int.tryParse('${chosen['contentLength'] ?? ''}'),
    );
  }

  int _height(Map format) {
    final height = format['height'];
    if (height is num) return height.toInt();
    final label = '${format['qualityLabel'] ?? ''}';
    return int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '') ?? 0;
  }

  String _extFor(String mimeType) {
    if (mimeType.startsWith('audio/mp4')) return 'm4a';
    if (mimeType.contains('opus')) return 'opus';
    if (mimeType.startsWith('audio/webm')) return 'webm';
    if (mimeType.startsWith('video/mp4')) return 'mp4';
    return 'm4a';
  }

  void _cacheStream(String key, StreamInfo info) {
    _streamCache[key] = _CacheEntry(info);
    if (_streamCache.length <= _maxStreamCacheEntries) return;

    final oldest = _streamCache.entries
        .reduce((a, b) => a.value.storedAt.isBefore(b.value.storedAt) ? a : b);
    _streamCache.remove(oldest.key);
  }

  @override
  Future<void> prefetch(List<String> videoIds) async {
    final pending = videoIds
        .where((id) => id.isNotEmpty)
        .where((id) => !_streamCache.containsKey('$id:audio'))
        .where((id) => !_prefetching.contains(id))
        .take(_maxConcurrentPrefetch)
        .toList();

    await Future.wait(pending.map((id) async {
      _prefetching.add(id);
      try {
        await getStreamInfo(id);
      } catch (_) {
        // Prefetch is best-effort; playback will retry on demand.
      } finally {
        _prefetching.remove(id);
      }
    }));
  }

  // ── Suggestions / autoplay ────────────────────────────────────────────────

  @override
  Future<List<VideoModel>> getSuggestions(
    String videoId, {
    String title = '',
    String uploader = '',
  }) async {
    try {
      final radio = await _radioSuggestions(videoId);
      if (radio.length >= 5) return radio;
      final text = await _textSuggestions(videoId, title, uploader);
      return text.isNotEmpty ? text : radio;
    } catch (_) {
      return [];
    }
  }

  /// YouTube's own "radio" mix for the track — the closest match to what the
  /// server got out of yt-dlp's `RD{id}` playlist.
  Future<List<VideoModel>> _radioSuggestions(String videoId) async {
    final response = await _tube.call('next', {
      'videoId': videoId,
      'playlistId': 'RD$videoId',
    });

    return InnertubeParser.videosFrom(
      response['contents'],
      seen: {videoId},
    ).where(_isMusic).take(20).toList();
  }

  Future<List<VideoModel>> _textSuggestions(
    String videoId,
    String title,
    String uploader,
  ) async {
    final seen = <String>{videoId};
    final results = <VideoModel>[];

    final artist = _cleanArtist(uploader);
    if (artist != null) {
      final byArtist = await _tube.call('search', {'query': artist});
      results.addAll(
        InnertubeParser.videosFrom(byArtist['contents'], seen: seen)
            .where(_isMusic)
            .take(8),
      );
    }

    final query = _cleanSuggestionQuery(title, uploader);
    final byTitle = await _tube.call('search', {'query': query});
    results.addAll(
      InnertubeParser.videosFrom(byTitle['contents'], seen: seen)
          .where(_isMusic)
          .take(15 - results.length),
    );

    return results;
  }

  // ── Collections ───────────────────────────────────────────────────────────

  @override
  Future<CollectionModel> getPlaylist(String url) async {
    final playlistId = _playlistIdFrom(url);
    if (playlistId == null) throw Exception('Playlist não encontrada: $url');

    final response = await _tube.call('browse', {'browseId': 'VL$playlistId'});
    var tracks = InnertubeParser.videosFrom(response['contents']);

    // Older layouts only answer the ANDROID client with parseable renderers.
    if (tracks.isEmpty) {
      final fallback = await _tube.call(
        'browse',
        {'browseId': 'VL$playlistId'},
        client: InnertubeClient.android,
      );
      tracks = InnertubeParser.videosFrom(fallback['contents']);
    }
    if (tracks.isEmpty) throw Exception('Playlist vazia ou indisponível');

    final header = InnertubeParser.findFirst(response, 'pageHeaderViewModel');
    final title = InnertubeParser.readText(
          InnertubeParser.findFirst(header, 'dynamicTextViewModel')?['text'],
        ) ??
        'Playlist';

    unawaited(prefetch(tracks.take(5).map((t) => t.id).toList()));

    return CollectionModel(
      id: playlistId,
      title: title,
      thumbnail:
          InnertubeParser.largestImage(header) ?? tracks.first.thumbnail,
      uploader: tracks.first.uploader,
      itemCount: tracks.length,
      items: tracks,
      type: url.contains('music.youtube.com')
          ? CollectionType.album
          : CollectionType.playlist,
      url: 'https://www.youtube.com/playlist?list=$playlistId',
    );
  }

  @override
  Future<CollectionModel> getChannel(String url) async {
    final channelId = await _resolveChannelId(url);
    if (channelId == null) throw Exception('Canal não encontrado: $url');

    final response = await _tube.call('browse', {
      'browseId': channelId,
      'params': _tabVideos,
    });

    final metadata =
        InnertubeParser.findFirst(response, 'channelMetadataRenderer');
    final name = metadata?['title'] as String? ??
        InnertubeParser.readText(
          InnertubeParser.findFirst(
            InnertubeParser.findFirst(response, 'pageHeaderViewModel'),
            'dynamicTextViewModel',
          )?['text'],
        ) ??
        'Canal';

    final videos = InnertubeParser.videosFrom(
      response['contents'],
      fallbackUploader: name,
    ).take(30).toList();

    if (videos.isNotEmpty) {
      unawaited(prefetch(videos.take(5).map((v) => v.id).toList()));
    }

    return CollectionModel(
      id: channelId,
      title: name,
      thumbnail: InnertubeParser.largestImage(metadata?['avatar']) ??
          InnertubeParser.largestImage(
            InnertubeParser.findFirst(response, 'pageHeaderViewModel')
                ?['image'],
          ),
      uploader: name,
      itemCount: videos.length,
      items: videos,
      type: CollectionType.channel,
      url: 'https://www.youtube.com/channel/$channelId',
    );
  }

  // ── Feeds ─────────────────────────────────────────────────────────────────

  @override
  Future<List<VideoModel>> getHomeFeed() async {
    final cached = _homeFeed;
    if (cached != null && !cached.isExpired(_feedTtl)) return cached.value;

    var videos = <VideoModel>[];
    try {
      // RDMM is YouTube's "My Mix" radio — the same seed the server used.
      final response = await _tube.call('next', {'playlistId': 'RDMM'});
      videos = InnertubeParser.videosFrom(response['contents'])
          .where(_isMusic)
          .take(20)
          .toList();
    } catch (_) {}

    if (videos.isEmpty) {
      try {
        videos = (await search('popular music hits')).where(_isMusic).take(20).toList();
      } catch (_) {
        return [];
      }
    }

    _homeFeed = _CacheEntry(videos);
    return videos;
  }

  @override
  Future<List<VideoModel>> getGenre(String hashtag) async {
    final key = hashtag.toLowerCase();
    final cached = _genreCache[key];
    if (cached != null && !cached.isExpired(_feedTtl)) return cached.value;

    try {
      final response = await _tube.call('search', {'query': '#$hashtag music'});
      final all = InnertubeParser.videosFrom(response['contents']);
      // Genres like lofi are mostly hour-long mixes, which the music filter
      // drops; fall back to the raw results rather than showing an empty tab.
      final filtered = all.where(_isMusic).toList();
      final videos = (filtered.length >= 5 ? filtered : all).take(20).toList();
      _genreCache[key] = _CacheEntry(videos);
      return videos;
    } catch (_) {
      return [];
    }
  }

  // ── Lyrics ────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getLyrics(String title, String artist) async {
    final result = await LyricsService.fetch(title, artist);
    return {
      'found': result.found,
      'plain_lyrics': result.plainLyrics,
      'synced_lyrics': result.syncedLyrics,
      'has_sync': result.hasSync,
    };
  }

  // ── Server-only features ──────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getStatus() async => const {
        'has_cookies_file': false,
        'has_firefox': false,
        'source': 'local',
      };

  /// Cookies live in the server's filesystem; there is nothing to upload here.
  @override
  Future<bool> uploadCookies(String content) async => false;

  @override
  Future<bool> deleteCookies() async => false;

  // ── Helpers ported from the API ───────────────────────────────────────────

  bool _isMusic(VideoModel video) {
    final duration = video.duration;
    if (duration != null && (duration < 60 || duration > 720)) return false;
    final title = video.title.toLowerCase();
    return !_nonMusicKeywords.any(title.contains);
  }

  /// Drops label-style channel names ("… - Topic", "SomethingVEVO") so the
  /// fallback search is seeded with a real artist.
  String? _cleanArtist(String uploader) {
    if (uploader.isEmpty) return null;
    final name = uploader
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();
    if (name.isEmpty || name.length > 40) return null;
    final lower = name.toLowerCase();
    if (_genericChannelWords.any(lower.contains)) return null;
    return name;
  }

  String _cleanSuggestionQuery(String title, String uploader) {
    var clean = title.replaceAll(
      RegExp(
        r'\s*[\(\[](lyrics?|official(?: music| audio| video)?|hq|4k|hd|'
        r'remaster(?:ed)?|full album|video clipe|clipe oficial|tradução|'
        r'legendado)[^\)\]]*[\)\]]\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    clean = InnertubeParser.collapseWhitespace(clean)
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .trim();

    if (clean.contains(' - ')) return clean;
    final artist = _cleanArtist(uploader);
    if (artist != null) return '$artist $clean'.trim();
    return clean.isEmpty ? 'music' : clean;
  }

  String? _playlistIdFrom(String url) {
    final fromQuery = Uri.tryParse(url)?.queryParameters['list'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

    final match = RegExp(r'(?:list=|/playlist/)([A-Za-z0-9_-]{10,})').firstMatch(url);
    if (match != null) return match.group(1);

    // A bare id was passed in.
    if (RegExp(r'^[A-Za-z0-9_-]{10,}$').hasMatch(url)) return url;
    return null;
  }

  Future<String?> _resolveChannelId(String url) async {
    final direct = RegExp(r'(UC[A-Za-z0-9_-]{22})').firstMatch(url);
    if (direct != null) return direct.group(1);

    var target = url;
    if (!target.startsWith('http')) {
      target = target.startsWith('@')
          ? 'https://www.youtube.com/$target'
          : 'https://www.youtube.com/@$target';
    }

    try {
      final response =
          await _tube.call('navigation/resolve_url', {'url': target});
      final browseId =
          InnertubeParser.findFirst(response, 'browseEndpoint')?['browseId'];
      if (browseId is String && browseId.startsWith('UC')) return browseId;
    } catch (_) {}
    return null;
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime storedAt;

  _CacheEntry(this.value) : storedAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}
