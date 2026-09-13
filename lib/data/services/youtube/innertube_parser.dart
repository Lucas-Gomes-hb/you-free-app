import '../../models/video_model.dart';
import '../../models/collection_model.dart';

/// Turns raw InnerTube JSON into app models.
///
/// YouTube ships several renderer shapes for the same entity and swaps them
/// without notice (the newer `lockupViewModel` is replacing the classic
/// `videoRenderer` tab by tab), so every extractor walks the tree by key and
/// tolerates whichever shape comes back.
class InnertubeParser {
  static final _durationPattern = RegExp(r'^\d{1,2}(:\d{2}){1,2}$');
  static final _thumbSizePattern = RegExp(r'(sq|mq|sd|hq)?default\.jpg');
  static final _whitespacePattern = RegExp(r'\s+');

  /// Collects every value stored under [key], at any depth.
  static List<Map<String, dynamic>> findAll(dynamic node, String key) {
    final out = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map) {
        final value = n[key];
        if (value is Map) out.add(Map<String, dynamic>.from(value));
        for (final v in n.values) {
          walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(node);
    return out;
  }

  static Map<String, dynamic>? findFirst(dynamic node, String key) {
    final all = findAll(node, key);
    return all.isEmpty ? null : all.first;
  }

  /// Collects every scalar stored under [key], at any depth.
  static List<dynamic> findAllValues(dynamic node, String key) {
    final out = <dynamic>[];
    void walk(dynamic n) {
      if (n is Map) {
        if (n.containsKey(key)) out.add(n[key]);
        for (final v in n.values) {
          walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(node);
    return out;
  }

  /// Reads YouTube's three interchangeable text shapes:
  /// `{simpleText}`, `{runs: [{text}]}` and `{content}`.
  static String? readText(dynamic node) {
    if (node == null) return null;
    if (node is String) return node.isEmpty ? null : node;
    if (node is! Map) return null;

    final simple = node['simpleText'];
    if (simple is String && simple.isNotEmpty) return simple;

    final content = node['content'];
    if (content is String && content.isNotEmpty) return content;

    final runs = node['runs'];
    if (runs is List && runs.isNotEmpty) {
      final buffer = runs
          .whereType<Map>()
          .map((r) => r['text'])
          .whereType<String>()
          .join();
      if (buffer.isNotEmpty) return buffer;
    }
    return null;
  }

  /// `"4:52"` -> 292, `"1:02:03"` -> 3723.
  static int? parseDuration(String? text) {
    if (text == null || !_durationPattern.hasMatch(text.trim())) return null;
    final parts = text.trim().split(':').map(int.parse).toList();
    return switch (parts.length) {
      2 => parts[0] * 60 + parts[1],
      3 => parts[0] * 3600 + parts[1] * 60 + parts[2],
      _ => null,
    };
  }

  /// Mirrors the server's `_best_thumb`: prefer the maxres variant, and fall
  /// back to deriving the URL from the video id when none is supplied.
  static String? bestThumb(String? url, String? videoId) {
    if (url == null || url.isEmpty) {
      return videoId == null
          ? null
          : 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
    }
    if (url.contains('i.ytimg.com/vi/')) {
      return url.replaceFirst(_thumbSizePattern, 'maxresdefault.jpg');
    }
    return url;
  }

  /// Largest image URL inside [node], regardless of the wrapper shape
  /// (`thumbnails` on classic renderers, `sources` on view models).
  static String? largestImage(dynamic node) {
    String? best;
    var bestWidth = -1;
    for (final key in const ['thumbnails', 'sources']) {
      for (final list in findAllValues(node, key)) {
        if (list is! List) continue;
        for (final item in list) {
          if (item is! Map) continue;
          final url = item['url'];
          if (url is! String || url.isEmpty) continue;
          final width = (item['width'] as num?)?.toInt() ?? 0;
          if (width > bestWidth) {
            bestWidth = width;
            best = url;
          }
        }
      }
    }
    return best;
  }

  static bool isVideoId(String? id) => id != null && id.length == 11;

  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  // ── Entity extractors ──────────────────────────────────────────────────────

  /// `videoRenderer`, `playlistVideoRenderer`, `playlistPanelVideoRenderer`,
  /// `compactVideoRenderer` and `gridVideoRenderer` all share these fields.
  static VideoModel? videoFromRenderer(
    Map<String, dynamic> renderer, {
    String? fallbackUploader,
  }) {
    final id = renderer['videoId'] as String? ??
        (findFirst(renderer['navigationEndpoint'], 'watchEndpoint')?['videoId']
            as String?);
    if (!isVideoId(id)) return null;

    final title = readText(renderer['title']);
    if (title == null) return null;

    final uploader = readText(renderer['ownerText']) ??
        readText(renderer['longBylineText']) ??
        readText(renderer['shortBylineText']) ??
        readText(renderer['author']) ??
        fallbackUploader;

    var duration = parseDuration(readText(renderer['lengthText']));
    duration ??= int.tryParse('${renderer['lengthSeconds'] ?? ''}');

    return VideoModel(
      id: id!,
      title: title,
      thumbnail: bestThumb(largestImage(renderer['thumbnail']), id),
      duration: duration,
      uploader: uploader,
      url: watchUrl(id),
    );
  }

  /// The newer `lockupViewModel`, used by channel tabs and playlist pages.
  static VideoModel? videoFromLockup(
    Map<String, dynamic> lockup, {
    String? fallbackUploader,
  }) {
    if (lockup['contentType'] != null &&
        lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') {
      return null;
    }
    final id = lockup['contentId'] as String?;
    if (!isVideoId(id)) return null;

    final metadata = findFirst(lockup, 'lockupMetadataViewModel');
    final title = readText(metadata?['title']);
    if (title == null) return null;

    // Duration lives in a thumbnail badge such as {"text": "3:51"}.
    int? duration;
    for (final badge in findAll(lockup, 'thumbnailBadgeViewModel')) {
      duration = parseDuration(badge['text'] as String?);
      if (duration != null) break;
    }

    return VideoModel(
      id: id!,
      title: title,
      thumbnail: bestThumb(largestImage(lockup['contentImage']), id),
      duration: duration,
      uploader: _lockupByline(metadata) ?? fallbackUploader,
      url: watchUrl(id),
    );
  }

  /// First metadata row that is neither a view count nor a relative date.
  static String? _lockupByline(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final part in findAll(metadata, 'text')) {
      final content = part['content'];
      if (content is! String || content.isEmpty) continue;
      final lower = content.toLowerCase();
      if (lower.contains('visualiz') ||
          lower.contains('view') ||
          lower.startsWith('há ') ||
          lower.contains(' ago') ||
          lower.contains('vídeo') ||
          lower.contains('video')) {
        continue;
      }
      return content;
    }
    return null;
  }

  /// Accepts both renderer families and returns whatever parses.
  static List<VideoModel> videosFrom(
    dynamic node, {
    String? fallbackUploader,
    Set<String>? seen,
    int? limit,
  }) {
    final ids = seen ?? <String>{};
    final out = <VideoModel>[];

    void add(VideoModel? video) {
      if (video == null || !ids.add(video.id)) return;
      out.add(video);
    }

    for (final key in const [
      'videoRenderer',
      'playlistVideoRenderer',
      'playlistPanelVideoRenderer',
      'compactVideoRenderer',
      'gridVideoRenderer',
    ]) {
      for (final renderer in findAll(node, key)) {
        if (limit != null && out.length >= limit) return out;
        add(videoFromRenderer(renderer, fallbackUploader: fallbackUploader));
      }
    }

    for (final lockup in findAll(node, 'lockupViewModel')) {
      if (limit != null && out.length >= limit) return out;
      add(videoFromLockup(lockup, fallbackUploader: fallbackUploader));
    }

    return out;
  }

  static ChannelInfo? channelFromRenderer(Map<String, dynamic> renderer) {
    final id = renderer['channelId'] as String?;
    final name = readText(renderer['title']);
    if (id == null || id.isEmpty || name == null) return null;

    final canonical = findFirst(renderer, 'browseEndpoint')?['canonicalBaseUrl']
        as String?;
    return ChannelInfo(
      id: id,
      name: name,
      thumbnail: largestImage(renderer['thumbnail']),
      url: canonical != null
          ? 'https://www.youtube.com$canonical'
          : 'https://www.youtube.com/channel/$id',
    );
  }

  static PlaylistPreview? playlistFromLockup(Map<String, dynamic> lockup) {
    if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_PLAYLIST' &&
        lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_ALBUM') {
      return null;
    }
    final id = lockup['contentId'] as String?;
    if (id == null || id.isEmpty) return null;

    final metadata = findFirst(lockup, 'lockupMetadataViewModel');
    final title = readText(metadata?['title']);
    if (title == null) return null;

    int? itemCount;
    for (final badge in findAll(lockup, 'thumbnailBadgeViewModel')) {
      final text = badge['text'];
      if (text is! String) continue;
      final match = RegExp(r'\d+').firstMatch(text.replaceAll('.', ''));
      if (match != null) {
        itemCount = int.tryParse(match.group(0)!);
        break;
      }
    }

    return PlaylistPreview(
      id: id,
      title: title,
      thumbnail: largestImage(lockup['contentImage']),
      uploader: _lockupByline(metadata),
      itemCount: itemCount,
      url: 'https://www.youtube.com/playlist?list=$id',
    );
  }

  /// Continuation token used to page search results and long playlists.
  static String? continuationToken(dynamic node) {
    for (final command in findAll(node, 'continuationCommand')) {
      final token = command['token'];
      if (token is String && token.isNotEmpty) return token;
    }
    return null;
  }

  static String collapseWhitespace(String value) =>
      value.replaceAll(_whitespacePattern, ' ').trim();
}
