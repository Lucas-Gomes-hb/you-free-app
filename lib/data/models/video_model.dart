class VideoModel {
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final String url;

  // ── Video-mode metadata ────────────────────────────────────────────────
  // Present on grid/list renderers, absent in the minimal music payloads, so
  // every field is optional and `toJson` omits the empty ones.
  final int? viewCount;
  final String? publishedText;
  final String? channelId;
  final String? channelThumbnail;
  final List<String> badges;

  /// Set when the entry was last opened on the Watch page rather than through
  /// the audio player.
  ///
  /// History is shared by both experiences, and the audio player records the
  /// video too — it owns the queue. Without this flag a music video watched in
  /// video mode comes back under "Recentemente ouvidas" and, tapped in music
  /// mode, plays as audio: the picture silently disappears.
  final bool playedAsVideo;

  VideoModel({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    required this.url,
    this.viewCount,
    this.publishedText,
    this.channelId,
    this.channelThumbnail,
    this.badges = const [],
    this.playedAsVideo = false,
  });

  VideoModel copyWith({bool? playedAsVideo}) => VideoModel(
        id: id,
        title: title,
        thumbnail: thumbnail,
        duration: duration,
        uploader: uploader,
        url: url,
        viewCount: viewCount,
        publishedText: publishedText,
        channelId: channelId,
        channelThumbnail: channelThumbnail,
        badges: badges,
        playedAsVideo: playedAsVideo ?? this.playedAsVideo,
      );

  /// Number plus a short letter run that may be a magnitude suffix, e.g.
  /// "1,2 mi", "1.2M", "13,5 mil". Capped so a trailing word such as
  /// "visualizações" cannot be swallowed whole.
  static final _viewCountPattern =
      RegExp(r'([\d.,]+)\s*([a-zA-ZçÇ]{0,6})');

  /// "1,2 mi de visualizações" / "1.2M views" -> 1200000.
  ///
  /// The suffix is resolved longest-first by prefix, never by a fixed
  /// alternation: pt-BR writes million as "mi" and thousand as "mil", while en
  /// writes "M"/"K". A naive `m` match reads "1,2 mi" as 12 million.
  static int? parseViewCount(String? text) {
    if (text == null) return null;
    final match = _viewCountPattern.firstMatch(text);
    if (match == null) return null;

    final base = _parseLocalizedNumber(match.group(1)!);
    if (base == null) return null;

    final suffix = (match.group(2) ?? '').toLowerCase();
    final multiplier = switch (suffix) {
      _ when suffix.startsWith('mil') => 1000.0,
      _ when suffix.startsWith('mi') => 1000000.0,
      _ when suffix.startsWith('m') => 1000000.0,
      _ when suffix.startsWith('bil') => 1000000000.0,
      _ when suffix.startsWith('b') => 1000000000.0,
      _ when suffix.startsWith('k') => 1000.0,
      _ => 1.0,
    };
    return (base * multiplier).round();
  }

  /// Reads a number written in either locale.
  ///
  /// A single separator followed by one or two digits is a decimal point
  /// ("1,2" = 1.2), while groups of exactly three digits are a thousands
  /// separator ("1.200.000"). Treating "1,2" as 12 would inflate every
  /// abbreviated count tenfold.
  static double? _parseLocalizedNumber(String raw) {
    final dots = '.'.allMatches(raw).length;
    final commas = ','.allMatches(raw).length;

    if (dots > 0 && commas > 0) {
      // Mixed separators: the rightmost one is the decimal point.
      final lastIsDot = raw.lastIndexOf('.') > raw.lastIndexOf(',');
      final parts = raw.split(lastIsDot ? '.' : ',');
      final whole = parts.first.replaceAll(
        lastIsDot ? ',' : '.',
        '',
      );
      return double.tryParse('$whole.${parts.sublist(1).join()}');
    }

    if (dots > 0 || commas > 0) {
      final separator = dots > 0 ? '.' : ',';
      final groups = raw.split(separator);
      final isThousands = groups.length > 2 ||
          groups.sublist(1).every((g) => g.length == 3);
      return isThousands
          ? double.tryParse(groups.join())
          : double.tryParse(groups.join('.'));
    }

    return double.tryParse(raw);
  }

  static String formatViewCount(int? count) {
    if (count == null) return '';
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} bi';
    }
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.', ',')} mi';
    }
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)} mil';
    return '$count';
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      duration: (json['duration'] as num?)?.toInt(),
      uploader: json['uploader'],
      url: json['url'] ?? '',
      viewCount: (json['view_count'] as num?)?.toInt() ??
          parseViewCount(json['view_count_text'] as String?),
      publishedText: json['published_text'],
      channelId: json['channel_id'],
      channelThumbnail: json['channel_thumbnail'],
      badges:
          (json['badges'] as List?)?.map((e) => '$e').toList() ?? const [],
      playedAsVideo: json['played_as_video'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'duration': duration,
      'uploader': uploader,
      'url': url,
      if (viewCount != null) 'view_count': viewCount,
      if (publishedText != null) 'published_text': publishedText,
      if (channelId != null) 'channel_id': channelId,
      if (channelThumbnail != null) 'channel_thumbnail': channelThumbnail,
      if (badges.isNotEmpty) 'badges': badges,
      if (playedAsVideo) 'played_as_video': true,
    };
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    final s = duration! % 60;
    final ss = s.toString().padLeft(2, '0');
    // YouTube omits the leading zero on minutes below an hour ("3:33",
    // not "03:33"), so the pad only applies when the hours are shown.
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  bool get isLive => badges.any((b) => b.toUpperCase().contains('AO VIVO'));

  /// "Canal · 1,2 mi de visualizações · há 3 dias", the metadata line under a
  /// video card. Returns only the parts that are actually known.
  String get metaLine {
    final parts = <String>[
      if (uploader != null && uploader!.isNotEmpty) uploader!,
      if (viewCount != null) '${formatViewCount(viewCount)} visualizações',
      if (publishedText != null && publishedText!.isNotEmpty) publishedText!,
    ];
    return parts.join(' · ');
  }
}

/// Full metadata for the watch page, where one video gets a whole screen.
class VideoDetails {
  final String id;
  final String title;
  final String? description;
  final String? channelId;
  final String? channelName;
  final String? channelThumbnail;
  final String? channelUrl;
  final String? subscriberCountText;
  final int? viewCount;
  final int? likeCount;
  final int? duration;
  final String? publishedText;
  final List<String> badges;
  final String? thumbnail;

  VideoDetails({
    required this.id,
    required this.title,
    this.description,
    this.channelId,
    this.channelName,
    this.channelThumbnail,
    this.channelUrl,
    this.subscriberCountText,
    this.viewCount,
    this.likeCount,
    this.duration,
    this.publishedText,
    this.badges = const [],
    this.thumbnail,
  });

  bool get isLive => badges.any((b) => b.toUpperCase().contains('AO VIVO'));

  factory VideoDetails.fromJson(Map<String, dynamic> json) {
    return VideoDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      channelId: json['channel_id'],
      channelName: json['channel_name'] ?? json['uploader'],
      channelThumbnail: json['channel_thumbnail'],
      channelUrl: json['channel_url'],
      subscriberCountText: json['subscriber_count_text'],
      viewCount: (json['view_count'] as num?)?.toInt() ??
          VideoModel.parseViewCount(json['view_count_text'] as String?),
      likeCount: (json['like_count'] as num?)?.toInt() ??
          VideoModel.parseViewCount(json['like_count_text'] as String?),
      duration: (json['duration'] as num?)?.toInt(),
      publishedText: json['published_text'],
      badges:
          (json['badges'] as List?)?.map((e) => '$e').toList() ?? const [],
      thumbnail: json['thumbnail'],
    );
  }

  /// Merges a feed card under the full metadata, so the watch page can be
  /// seeded from an already-loaded feed entry before the detail call lands.
  ///
  /// The freshly fetched details win wherever they carry a value and the card
  /// only fills the gaps, which is what lets the page render instantly with
  /// what the feed already knew and then refine itself.
  VideoDetails merge(VideoModel seed) => VideoDetails(
        id: id.isEmpty ? seed.id : id,
        title: title.isEmpty ? seed.title : title,
        description: description,
        channelId: channelId ?? seed.channelId,
        channelName: channelName ?? seed.uploader,
        channelThumbnail: channelThumbnail ?? seed.channelThumbnail,
        channelUrl: channelUrl,
        subscriberCountText: subscriberCountText,
        viewCount: viewCount ?? seed.viewCount,
        likeCount: likeCount,
        duration: duration ?? seed.duration,
        publishedText: publishedText ?? seed.publishedText,
        badges: badges.isNotEmpty ? badges : seed.badges,
        thumbnail: thumbnail ?? seed.thumbnail,
      );

  String get metaLine {
    final parts = <String>[
      if (viewCount != null)
        '${VideoModel.formatViewCount(viewCount)} visualizações',
      if (publishedText != null && publishedText!.isNotEmpty) publishedText!,
    ];
    return parts.join(' · ');
  }
}

class StreamFormat {
  final String formatId;
  final String url;
  final String ext;
  final String? quality;
  final int? filesize;

  StreamFormat({
    required this.formatId,
    required this.url,
    required this.ext,
    this.quality,
    this.filesize,
  });

  factory StreamFormat.fromJson(Map<String, dynamic> json) {
    return StreamFormat(
      formatId: json['format_id'] ?? '',
      url: json['url'] ?? '',
      ext: json['ext'] ?? '',
      quality: json['quality'],
      filesize: (json['filesize'] as num?)?.toInt(),
    );
  }
}

/// One rung of the video quality ladder.
///
/// Split streams carry no audio, so the player only pairs them with an audio
/// track when it is going through a DASH manifest. A progressive entry
/// ([isVideoOnly] false) is self-contained and can be swapped in on its own.
class VideoResolution {
  final String label;
  final int? height;
  final String url;
  final String? ext;
  final int? filesize;
  final bool isVideoOnly;

  /// Codec of the rendition, e.g. `avc1.64002a` or `av01.0.13M.08`. YouTube only
  /// offers 4K as AV1/VP9 while 1080p and below stay AVC, so this is what tells
  /// a player which rung a device can be trusted to decode.
  final String? vcodec;

  const VideoResolution({
    required this.label,
    required this.url,
    this.height,
    this.ext,
    this.filesize,
    this.vcodec,
    this.isVideoOnly = true,
  });

  factory VideoResolution.fromJson(Map<String, dynamic> json) {
    final height = (json['height'] as num?)?.toInt();
    return VideoResolution(
      label: json['label'] ?? (height != null ? '${height}p' : 'auto'),
      height: height,
      url: json['url'] ?? '',
      ext: json['ext'],
      filesize: (json['filesize'] as num?)?.toInt(),
      vcodec: json['vcodec'] as String?,
      isVideoOnly: json['is_video_only'] as bool? ?? true,
    );
  }
}

class StreamInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final List<StreamFormat> formats;
  final String? videoUrl;

  /// How [videoUrl] must be played: 'progressive' for a single mp4, 'hls' for
  /// the master manifest YouTube serves when only adaptive streams exist, and
  /// 'dash' for the MPD this API builds out of the split adaptive streams —
  /// the only shape that reaches 1080p and above *with* audio.
  final String? videoFormat;

  /// Every quality the API could offer, best first. Drives the player's quality
  /// menu; empty when the source has no ladder (muxed-only or HLS).
  final List<VideoResolution> videoResolutions;

  /// The proxied HLS master, when the API could offer one.
  ///
  /// Preferred over [videoUrl] for playback: every rendition in it is a list of
  /// short segments, so seeking fetches the one segment it lands on. The DASH
  /// rungs are single assets of up to 2 GB with an empty `sidx`, so a jump
  /// there re-reads from byte zero and the player looks hung.
  final String? hlsUrl;

  StreamInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    required this.formats,
    this.videoUrl,
    this.videoFormat,
    this.videoResolutions = const [],
    this.hlsUrl,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      duration: (json['duration'] as num?)?.toInt(),
      uploader: json['uploader'],
      formats: (json['formats'] as List?)
          ?.map((e) => StreamFormat.fromJson(e))
          .toList() ?? [],
      videoUrl: json['video_url'],
      videoFormat: json['video_format'],
      hlsUrl: json['hls_url'],
      videoResolutions: (json['video_resolutions'] as List?)
              ?.whereType<Map>()
              .map((e) => VideoResolution.fromJson(
                  e.map((k, v) => MapEntry('$k', v))))
              .where((e) => e.url.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  /// Rungs that can replace the current source on their own, i.e. the ones a
  /// player without DASH support can switch between.
  List<VideoResolution> get switchableResolutions =>
      videoResolutions.where((r) => !r.isVideoOnly).toList();

  /// Highest rung, used as the default quality.
  VideoResolution? get bestResolution =>
      videoResolutions.isEmpty ? null : videoResolutions.first;

  StreamFormat? get bestAudio {
    // Prefer audio-only containers, then combined mp4 (e.g. format 18), then anything
    final order = ['m4a', 'mp3', 'opus', 'webm', 'ogg', 'mp4'];
    for (final ext in order) {
      try {
        return formats.firstWhere((f) => f.ext == ext);
      } catch (_) {}
    }
    return formats.isNotEmpty ? formats.first : null;
  }

  StreamFormat? get bestVideo {
    try {
      return formats.firstWhere((f) => f.ext == 'mp4' && f.quality != null);
    } catch (_) {
      return formats.isNotEmpty ? formats.first : null;
    }
  }
}