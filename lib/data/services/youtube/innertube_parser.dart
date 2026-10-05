import '../../models/comment_model.dart';
import '../../models/video_model.dart';
import '../../models/collection_model.dart';
import '../../models/search_filter_option.dart';

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

  /// Collects every *list* stored under [key], at any depth.
  ///
  /// [findAll] only returns maps, which misses every place YouTube keys a
  /// collection of renderers by name — `topLevelButtons` in the action row is
  /// the one that matters most, since the like count lives inside it.
  static List<dynamic> findAllLists(dynamic node, String key) {
    final out = <dynamic>[];
    void walk(dynamic n) {
      if (n is Map) {
        final value = n[key];
        if (value is List) out.add(value);
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
  ///
  /// Falls back to the accessibility label, which is where several counters
  /// live on their own: the segmented like button carries "2,8 mil curtidas"
  /// only under `accessibility`, with no visible text at all.
  /// Strips the zero-width and bidi control characters YouTube leaves inside
  /// labels, which would otherwise render as stray glyphs or flip the reading
  /// direction of a whole string.
  static final RegExp _invisible = RegExp('[\u200B-\u200F\u202A-\u202E'
      '\u2060-\u2064\uFEFF]');

  static String? _cleanText(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceAll(_invisible, '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? readText(dynamic node) {
    if (node == null) return null;
    if (node is String) return _cleanText(node);
    if (node is! Map) return null;

    final simple = node['simpleText'];
    if (simple is String && simple.isNotEmpty) return _cleanText(simple);

    final content = node['content'];
    if (content is String && content.isNotEmpty) return _cleanText(content);

    final runs = node['runs'];
    if (runs is List && runs.isNotEmpty) {
      final buffer = runs
          .whereType<Map>()
          .map((r) => r['text'])
          .whereType<String>()
          .join();
      if (buffer.isNotEmpty) return _cleanText(buffer);
    }

    for (final key in const ['accessibility', 'accessibilityData']) {
      final holder = node[key];
      if (holder is String && holder.isNotEmpty) return _cleanText(holder);
      if (holder is! Map) continue;
      final nested = holder['accessibilityData'];
      for (final label in [
        holder['label'],
        if (nested is Map) nested['label'],
      ]) {
        if (label is String && label.isNotEmpty) return _cleanText(label);
      }
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

  // ── Shared metadata readers ────────────────────────────────────────────────

  /// "1,2 mi de visualizações" / "1.2M views" / "12 mil views" -> 1200000.
  static int? parseViewCount(dynamic node) {
    final text = readText(node);
    if (text == null) return null;
    if (!RegExp(r'\d').hasMatch(text)) return null;
    return VideoModel.parseViewCount(text);
  }

  /// The relative date YouTube shows next to the view count, e.g. "há 3 dias".
  /// Kept as text: the exact unit wording differs per locale and the app has
  /// no need to compute an absolute date from it.
  static String? relativePublishedText(Map<String, dynamic> renderer) {
    final candidates = <dynamic>[
      renderer['publishedTimeText'],
      renderer['publishedText'],
    ];
    for (final part in findAll(renderer, 'text')) {
      final content = part['content'];
      if (content is String && content.toLowerCase().startsWith('há ')) {
        candidates.add(content);
      }
    }
    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) return candidate;
      final text = readText(candidate);
      if (text != null && text.toLowerCase().startsWith('há ')) return text;
    }
    return null;
  }

  /// Thumbnail badges such as "AO VIVO", "CC" or "4K".
  static List<String> badgesFrom(Map<String, dynamic> renderer) {
    final badges = <String>[];
    for (final key in const [
      'thumbnailOverlayTimeStatusRenderer',
      'badges',
    ]) {
      for (final node in findAll(renderer, key)) {
        final style = readText(node['style']);
        final label = readText(node['text']) ?? readText(node['label']);
        if (label != null) badges.add(label);
        if (style != null && style.toUpperCase() == 'BADGE_STYLE_TYPE_LIVE_NOW') {
          badges.add('AO VIVO');
        }
      }
    }
    for (final node in findAll(renderer, 'badges')) {
      final label = readText(node['metadataBadgeRenderer']?['label']) ??
          readText(node['label']);
      if (label != null) badges.add(label);
    }
    return badges.toSet().toList();
  }

  /// Channel avatar plus id, which grid cards carry but list rows often drop.
  static ({String? id, String? thumbnail})? channelMetaFrom(
    Map<String, dynamic> renderer,
  ) {
    final id = renderer['channelId'] as String? ??
        (findFirst(renderer, 'browseEndpoint')?['browseId'] as String?);
    String? thumbnail;
    for (final key in const ['channelThumbnailSupportedRenderers', 'avatar']) {
      final node = findFirst(renderer, key);
      if (node != null) {
        thumbnail = largestImage(node);
        if (thumbnail != null) break;
      }
    }
    if (id == null && thumbnail == null) return null;
    return (id: id, thumbnail: thumbnail);
  }

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

    final channel = channelMetaFrom(renderer);
    return VideoModel(
      id: id!,
      title: title,
      thumbnail: bestThumb(largestImage(renderer['thumbnail']), id),
      duration: duration,
      uploader: uploader,
      url: watchUrl(id),
      viewCount: parseViewCount(renderer['viewCountText']) ??
          parseViewCount(renderer['shortViewCountText']),
      publishedText: relativePublishedText(renderer),
      channelId: channel?.id,
      channelThumbnail: channel?.thumbnail,
      badges: badgesFrom(renderer),
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

    // Duration lives in a thumbnail badge such as {"text": "3:51"}. Those
    // badges are never counts, so they must not feed the view total.
    int? duration;
    final badges = <String>[];
    for (final badge in findAll(lockup, 'thumbnailBadgeViewModel')) {
      final text = badge['text'] as String?;
      if (text != null) duration ??= parseDuration(text);
      if (badge['icon'] != null && text != null) badges.add(text);
    }

    // Channel, views and age arrive interleaved as plain text parts. The first
    // is always the channel and the views are the first later part that parses
    // as a count, with the age right after it. Matching on words such as
    // "visualizações" would break on any other UI language, and the abbreviated
    // form ("1,4 mi") does not always carry the word at all.
    final parts = <String>[];
    for (final part in findAll(metadata, 'text')) {
      final content = part['content'];
      if (content is String && content.trim().isNotEmpty) {
        parts.add(content.trim());
      }
    }

    int? views;
    String? published;
    for (var i = 1; i < parts.length; i++) {
      final parsed = VideoModel.parseViewCount(parts[i]);
      if (parsed != null) {
        views = parsed;
        if (i + 1 < parts.length) published = parts[i + 1];
        break;
      }
    }

    return VideoModel(
      id: id!,
      title: title,
      thumbnail: bestThumb(largestImage(lockup['contentImage']), id),
      duration: duration,
      uploader: _lockupByline(metadata) ?? fallbackUploader,
      url: watchUrl(id),
      viewCount: views,
      publishedText: published ?? relativePublishedText(lockup),
      badges: badges,
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
  /// Yields every video entry as `(key, renderer)` in document order.
  ///
  /// A single list can mix shapes: YouTube serves the older `*Renderer` items
  /// next to `lockupViewModel` ones, so walking once per key would scramble the
  /// order the user actually sees.
  static Iterable<MapEntry<String, dynamic>> _videoEntries(
    dynamic node, [
    int depth = 0,
  ]) sync* {
    if (depth > _maxDepth) return;
    if (node is List) {
      for (final item in node) {
        yield* _videoEntries(item, depth + 1);
      }
      return;
    }
    if (node is! Map) return;
    for (final entry in node.entries) {
      if (_videoRendererKeys.contains(entry.key) ||
          entry.key == 'lockupViewModel') {
        if (entry.value is Map) {
          yield MapEntry(entry.key, entry.value as Map<String, dynamic>);
        }
      } else {
        yield* _videoEntries(entry.value, depth + 1);
      }
    }
  }

  static const Set<String> _videoRendererKeys = {
    'videoRenderer',
    'playlistVideoRenderer',
    'playlistPanelVideoRenderer',
    'compactVideoRenderer',
    'gridVideoRenderer',
  };

  /// Depth guard for the recursive walk. InnerTube payloads nest far deeper
  /// than this in a few places (engagement panels, entity bundles), so the cap
  /// is generous but keeps a malformed response from overflowing the stack.
  static const int _maxDepth = 40;

  static List<VideoModel> videosFrom(
    dynamic node, {
    String? fallbackUploader,
    Set<String>? seen,
    int? limit,
  }) {
    final ids = seen ?? <String>{};
    final out = <VideoModel>[];

    for (final entry in _videoEntries(node)) {
      if (limit != null && out.length >= limit) break;
      final video = entry.key == 'lockupViewModel'
          ? videoFromLockup(entry.value, fallbackUploader: fallbackUploader)
          : videoFromRenderer(entry.value, fallbackUploader: fallbackUploader);
      if (video == null || !ids.add(video.id)) continue;
      out.add(video);
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
  /// Continuation that boots the comment section in one given ordering.
  ///
  /// Only the sort menu knows how to order: each of its options carries its own
  /// continuation, so reading the pinned token for a "Recentes" request returns
  /// the top comments again. Returns null for any ordering that does not have
  /// its own token, which leaves the default section token in place.
  static String? commentSortToken(dynamic node, String sort) {
    if (sort != 'newest') return null;
    for (final list in findAllLists(node, 'subMenuItems')) {
      if (list is! List) continue;
      for (final item in list) {
        if (item is! Map) continue;
        final title = readText(item['title'])?.toLowerCase();
        if (title != 'mais recentes') continue;
        final endpoint = item['serviceEndpoint'];
        if (endpoint is! Map) continue;
        final command = endpoint['continuationCommand'];
        final token = command is Map ? readText(command['token']) : null;
        if (token != null && token.isNotEmpty) return token;
      }
    }
    return null;
  }

  static String? continuationToken(dynamic node) {
    for (final command in findAll(node, 'continuationCommand')) {
      final token = command['token'];
      if (token is String && token.isNotEmpty) return token;
    }
    return null;
  }

  // ── Watch page ─────────────────────────────────────────────────────────────

  /// Full metadata for the watch page, read from the player response plus the
  /// surrounding watch-next metadata. The title/duration also appear in the
  /// player response, so those are read first and the renderers act as backup.
  static VideoDetails? videoDetailsFrom(dynamic node, String videoId) {
    if (!isVideoId(videoId)) return null;

    // The caller may hand over a merged `{next, player}` bundle (the two
    // endpoints complement each other), or just one of the two payloads.
    final merged = node is Map && (node['next'] is Map || node['player'] is Map);
    final watch = merged ? (node['next'] ?? node) as dynamic : node;
    final playerNode = merged ? (node['player'] ?? node) as dynamic : node;

    final player = findFirst(playerNode, 'videoDetails');
    final primary = findFirst(watch, 'videoPrimaryInfoRenderer');
    final secondary = findFirst(watch, 'videoSecondaryInfoRenderer');
    final owner = findFirst(secondary, 'videoOwnerRenderer');

    final title = (player?['title'] as String?) ??
        readText(primary?['title']) ??
        readText(findFirst(watch, 'videoRenderer')?['title']);
    if (title == null || title.isEmpty) return null;

    final views = _asInt(player?['viewCount']) ??
        _viewCountFromPrimary(primary) ??
        parseViewCount(primary?['viewCount']);

    final microformat = findFirst(watch, 'videoMicroformatRenderer');
    // "AO VIVO NOW" lives in a thumbnail overlay on the primary renderer.
    final liveOverlay =
        findFirst(primary, 'thumbnailOverlayTimeStatusRenderer');
    final badges = <String>[
      ...badgesFrom(primary ?? const {}),
      if (liveOverlay != null) 'AO VIVO',
    ];

    final channelThumbNode = owner == null
        ? null
        : (findFirst(owner, 'thumbnails') ??
            findFirst(owner, 'avatar') ??
            findFirst(owner, 'videoOwnerRenderer') ??
            owner);

    return VideoDetails(
      id: videoId,
      title: collapseWhitespace(title),
      description: readText(secondary?['attributedDescription']) ??
          readText(secondary?['description']) ??
          player?['shortDescription'] as String? ??
          microformat?['description'] as String?,
      channelId: owner?['navigationEndpoint']?['browseEndpoint']?['browseId']
          as String? ??
          microformat?['ownerChannelName'] as String?,
      channelName: readText(owner?['title']) ??
          microformat?['ownerChannelName'] as String?,
      channelThumbnail:
          channelThumbNode == null ? null : largestImage(channelThumbNode),
      channelUrl: _browseUrl(findFirst(owner, 'browseEndpoint')),
      subscriberCountText: readText(owner?['subscriberCountText']),
      viewCount: views,
      likeCount: _likeCountFrom(primary, secondary),
      duration: _asInt(player?['lengthSeconds']) ??
          parseDuration(readText(primary?['lengthText'])),
      publishedText: readText(primary?['dateText']) ??
          microformat?['publishDate'] as String?,
      badges: badges.toSet().toList(),
      thumbnail: bestThumb(
          largestImage(findFirst(watch, 'videoRenderer')?['thumbnail']),
          videoId),
    );
  }

  static String? _browseUrl(Map<String, dynamic>? browseEndpoint) {
    final canonical = browseEndpoint?['canonicalBaseUrl'] as String?;
    if (canonical != null) return 'https://www.youtube.com$canonical';
    final browseId = browseEndpoint?['browseId'] as String?;
    return browseId == null ? null : 'https://www.youtube.com/channel/$browseId';
  }

  /// The like count hides in the action row. The current payload is a stack of
  /// self-nesting `*ViewModel` keys whose button is only identifiable by
  /// `iconName`, with the number sitting in its `title`; older answers use
  /// `toggleButtonRenderer` with an accessibility label that is the bare count
  /// with no mention of likes, so that one falls back to position.
  static int? _likeCountFrom(
    dynamic primary,
    Map<String, dynamic>? secondary,
  ) {
    for (final node in findAll(primary ?? secondary, 'buttonViewModel')) {
      final iconName = node['iconName'];
      if (iconName is! String || iconName.toUpperCase() != 'LIKE') continue;
      final title = node['title'];
      final parsed = VideoModel.parseViewCount(
          title is String ? title : readText(title as dynamic));
      if (parsed != null) return parsed;
    }

    for (final holder in [primary, secondary]) {
      if (holder == null) continue;
      for (final row in findAllLists(holder, 'topLevelButtons')) {
        for (final button in findAll(row, 'toggleButtonRenderer')) {
          final label =
              readText(button['defaultText']) ?? readText(button);
          final parsed = VideoModel.parseViewCount(label);
          if (parsed != null) return parsed;
        }
      }
    }

    // Older payloads spell it out in a dedicated field.
    return VideoModel.parseViewCount(
        readText(findFirst(secondary, 'likeCount')));
  }

  /// The view count on the watch page is nested one level below where the field
  /// name suggests: `viewCount.videoViewCountRenderer.viewCount`.
  static int? _viewCountFromPrimary(dynamic primary) {
    if (primary is! Map) return null;
    final holder = primary['viewCount'];
    if (holder is! Map) return null;
    final renderer = holder['videoViewCountRenderer'];
    if (renderer is Map) {
      for (final key in const ['viewCount', 'shortViewCount']) {
        final parsed = parseViewCount(renderer[key]);
        if (parsed != null) return parsed;
      }
      final exact = _asInt(renderer['originalViewCount']);
      if (exact != null) return exact;
    }
    return parseViewCount(holder);
  }

  /// InnerTube is inconsistent about numeric types: `lengthSeconds` and
  /// `viewCount` arrive as strings in the player response and as numbers in the
  /// web response, so every read has to tolerate both.
  static int? _asInt(dynamic value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };

  /// A page of top-level comments, skipping the "header" placeholder rows and
  /// the nested reply renderers so each video appears once.
  static CommentPage commentsFrom(dynamic node) {
    // Current payloads use the entity protocol, so it is tried first; the
    // legacy renderers remain as a fallback for older answers.
    final entities = _commentsFromEntities(node);
    if (entities.isNotEmpty) {
      return CommentPage(
        comments: entities,
        continuation: continuationToken(node),
      );
    }

    final comments = <VideoComment>[];
    final seen = <String>{};

    for (final thread in _topLevel(node, 'commentThreadRenderer')) {
      final comment = _commentFromThread(thread);
      if (comment == null || !seen.add(comment.id)) continue;
      comments.add(comment);
    }

    // Some responses drop the thread wrapper and return the renderer directly.
    for (final renderer in _topLevel(node, 'commentRenderer')) {
      final comment = _commentFromRenderer(renderer);
      if (comment == null || !seen.add(comment.id)) continue;
      comments.add(comment);
    }

    return CommentPage(
      comments: comments,
      continuation: continuationToken(node),
    );
  }

  /// Reads the entity-batch protocol YouTube moved comment paging to.
  ///
  /// A continuation answers with `continuationItems` holding `commentViewModel`
  /// *references* — order, pinning and thread structure — plus a flat
  /// `frameworkUpdates` batch carrying the `commentEntityPayload` bodies keyed
  /// by the same opaque key. Walking the references in order is what preserves
  /// the user's sort, since the batch itself has lost it.
  static List<VideoComment> _commentsFromEntities(dynamic node) {
    final bodies = <String, Map<String, dynamic>>{};
    for (final entity in findAll(node, 'commentEntityPayload')) {
      final key = entity['key'];
      if (key is String) bodies[key] = entity;
    }
    if (bodies.isEmpty) return const [];

    final hearted = <String>{};
    for (final state in findAll(node, 'engagementToolbarStateEntityPayload')) {
      final key = state['key'];
      // `endsWith` rather than a substring test: the unhearted value is
      // `..._UNHEARTED`, which contains "HEARTED" but means the opposite.
      if (key is String &&
          (state['heartState'] as String? ?? '').endsWith('_HEARTED')) {
        hearted.add(key);
      }
    }

    final out = <VideoComment>[];
    final seen = <String>{};

    /// The key is self-nesting (`commentViewModel.commentViewModel`), so the
    /// body sits one level below whatever the first lookup returns.
    Map<String, dynamic>? unwrap(dynamic reference) {
      var current = reference;
      while (current is Map && !current.containsKey('commentKey')) {
        current = findFirst(current, 'commentViewModel');
        if (current is! Map) return null;
      }
      return current is Map ? current.cast<String, dynamic>() : null;
    }

    final command = findFirst(node, 'reloadContinuationItemsCommand');
    final items = command?['continuationItems'];
    final references = <Map<String, dynamic>>[];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final thread = findFirst(item, 'commentThreadRenderer');
        if (thread is! Map) continue;
        final reference = unwrap(findFirst(thread, 'commentViewModel'));
        if (reference != null) references.add(reference);
      }
    }

    for (final reference in references) {
      final body = bodies[reference['commentKey']];
      if (body == null) continue;
      final comment = _commentFromEntity(
        body,
        hearted: hearted.contains(reference['toolbarStateKey']),
        pinned: (reference['pinnedText'] as String? ?? '').isNotEmpty,
      );
      if (comment == null || !seen.add(comment.id)) continue;
      out.add(comment);
    }

    if (out.isEmpty) {
      // Some responses answer with the batch only, so fall back to its order.
      for (final body in bodies.values) {
        final comment = _commentFromEntity(
          body,
          hearted: hearted.contains(body['key']),
        );
        if (comment == null || !seen.add(comment.id)) continue;
        out.add(comment);
      }
    }
    return out;
  }

  /// Builds a comment from the `commentEntityPayload` shape, where content,
  /// author and counts all live in the same payload.
  static VideoComment? _commentFromEntity(
    Map<String, dynamic> entity, {
    required bool hearted,
    bool pinned = false,
  }) {
    final properties = (entity['properties'] as Map?)?.cast<String, dynamic>();
    if (properties == null) return null;
    final text = readText(properties['content']);
    if (text == null) return null;

    final author = (entity['author'] as Map?)?.cast<String, dynamic>();
    final toolbar = (entity['toolbar'] as Map?)?.cast<String, dynamic>();
    return VideoComment(
      id: (properties['commentId'] as String?) ?? (entity['key'] as String? ?? ''),
      authorId: (author?['channelId'] as String?) ?? '',
      authorName:
          ((author?['displayName'] as String?) ?? '').replaceFirst('@', ''),
      authorThumbnail: author?['avatarThumbnailUrl'] as String?,
      text: collapseWhitespace(text),
      likeCount: VideoModel.parseViewCount(
            toolbar?['likeCountNotliked'] ?? toolbar?['likeCountLiked'],
          ) ??
          0,
      publishedText: readText(properties['publishedTime']),
      replyCount: VideoModel.parseViewCount(toolbar?['replyCount']) ?? 0,
      isCreatorHearted: hearted,
      isPinned: pinned,
    );
  }

  /// Collects values stored under [key] while refusing to descend into any
  /// thread already collected.
  ///
  /// A reply is itself a `commentThreadRenderer` nested inside
  /// `commentRepliesRenderer`, so a plain depth-first walk reports replies as
  /// if they were top-level comments. Stopping at the outermost occurrence of
  /// either thread or renderer key keeps replies with their parent.
  static List<Map<String, dynamic>> _topLevel(dynamic node, String key) {
    final out = <Map<String, dynamic>>[];
    final descend = key == 'commentThreadRenderer'
        ? const ['commentThreadRenderer', 'commentRenderer']
        : const ['commentThreadRenderer'];

    void walk(dynamic n) {
      if (n is Map) {
        for (final entry in n.entries) {
          final value = entry.value;
          if (entry.key == key && value is Map) {
            out.add(Map<String, dynamic>.from(value));
            continue;
          }
          if (descend.contains(entry.key)) continue;
          walk(value);
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

  static VideoComment? _commentFromThread(Map<String, dynamic> thread) {
    final renderer =
        findFirst(thread['comments'], 'commentRenderer') ??
            findFirst(thread, 'commentRenderer');
    if (renderer == null) return null;
    final comment = _commentFromRenderer(renderer);
    if (comment == null) return null;

    // Replies are nested in the thread rather than repeated at top level, and
    // YouTube ships two shapes for them: a flat `commentReplyRenderer` list or
    // a `commentRepliesRenderer` holding one thread per reply. Count whichever
    // is present without double-counting.
    final replyCount = _replyCountIn(thread);

    final isPinned = findFirst(thread, 'pinnedCommentBadge') != null ||
        readText(findFirst(thread, 'pinnedText')) != null;

    return VideoComment(
      id: comment.id,
      authorId: comment.authorId,
      authorName: comment.authorName,
      authorThumbnail: comment.authorThumbnail,
      text: comment.text,
      likeCount: comment.likeCount,
      publishedText: comment.publishedText,
      replyCount: replyCount,
      isCreatorHearted: comment.isCreatorHearted,
      isPinned: isPinned,
    );
  }

  /// The larger of the two reply shapes, since a thread never uses both.
  static int _replyCountIn(Map<String, dynamic> thread) {
    final flat = findAll(thread, 'commentReplyRenderer').length;
    var nested = 0;
    for (final container in findAll(thread, 'commentRepliesRenderer')) {
      nested += _topLevel(container, 'commentThreadRenderer').length;
    }
    return flat > nested ? flat : nested;
  }

  static VideoComment? _commentFromRenderer(Map<String, dynamic> renderer) {
    final text = readText(renderer['contentText']);
    if (text == null || text.isEmpty) return null;

    final authorId =
        renderer['authorId'] as String? ??
            (renderer['authorEndpoint']?['browseEndpoint']?['browseId']
                as String?);
    final id = renderer['commentId'] as String?;
    if (id == null && authorId == null) return null;

    final viewModel = findFirst(renderer, 'commentViewModel');
    final heart =
        findFirst(renderer, 'creatorHeart') != null ||
            (viewModel?['authorIsCreator'] == true);

    return VideoComment(
      // Ids are optional in YouTube's payload; fall back to a stable synthetic
      // key so de-duplication and list keys still work.
      id: id ?? 'cmt_${authorId}_${text.hashCode}',
      authorId: authorId ?? '',
      authorName: readText(renderer['authorText']),
      authorThumbnail: largestImage(findFirst(renderer, 'authorThumbnail')),
      text: collapseWhitespace(text),
      likeCount: parseViewCount(
              findFirst(renderer, 'voteCount') ??
                  findFirst(renderer, 'voteCountSimple') ??
                  findFirst(renderer, 'likeCountNotliked') ??
                  const {})
          ??
          0,
      publishedText: readText(renderer['publishedTimeText']),
      isCreatorHearted: heart,
    );
  }

  static String collapseWhitespace(String value) =>
      value.replaceAll(_whitespacePattern, ' ').trim();

  // ── Search filters ─────────────────────────────────────────────────────────

  /// Reads the refinement bar above the results (upload date, duration, type,
  /// sort by) out of a search response.
  ///
  /// Each chip carries a *complete* `params` value for the search it would
  /// run, valid only alongside the filters already applied — which is why the
  /// options have to be re-read from the filtered response instead of being
  /// merged locally.
  static List<SearchFilterOption> searchFiltersFrom(dynamic node) {
    final options = <SearchFilterOption>[];
    final seen = <String>{};

    for (final key in const [
      'searchFilterRenderer',
      'filterChipRenderer',
    ]) {
      for (final chip in findAll(node, key)) {
        final params = _searchEndpointParams(chip);
        if (params == null || !seen.add(params)) continue;

        final label = readText(chip['label']) ??
            readText(findFirst(chip, 'text'));
        if (label == null || label.isEmpty) continue;

        final icon = readText(findFirst(chip, 'icon')?['iconType']);
        options.add(SearchFilterOption(
          value: params,
          label: label,
          iconHint: icon,
        ));
      }
    }

    return options;
  }

  /// The `params` of the search request a chip would issue, which is what makes
  /// the chip the authoritative filter value.
  static String? _searchEndpointParams(Map<String, dynamic> chip) {
    for (final key in const [
      'searchEndpoint',
      'navigationEndpoint',
      'serviceEndpoint',
    ]) {
      for (final endpoint in findAll(chip, key)) {
        final params = endpoint['params'];
        if (params is String && params.isNotEmpty) return params;
        // Watch-next filters (the "live now" rail) nest the endpoint one level
        // deeper under a search-filter continuation.
        final nested = endpoint['continuationCommand']?['request'] ??
            endpoint['clickTracking'];
        if (nested is Map) {
          final inner = nested['params'];
          if (inner is String && inner.isNotEmpty) return inner;
        }
      }
    }
    return null;
  }
}
