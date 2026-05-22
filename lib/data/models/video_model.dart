class VideoModel {
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final String url;

  VideoModel({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    required this.url,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      duration: (json['duration'] as num?)?.toInt(),
      uploader: json['uploader'],
      url: json['url'] ?? '',
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
    };
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    final s = duration! % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
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

class StreamInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final List<StreamFormat> formats;
  final String? videoUrl;

  StreamInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    required this.formats,
    this.videoUrl,
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
    );
  }

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