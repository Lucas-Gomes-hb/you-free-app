import 'video_model.dart';

enum CollectionType { album, playlist, channel }

extension CollectionTypeLabel on CollectionType {
  String get label {
    switch (this) {
      case CollectionType.album:
        return 'Álbum';
      case CollectionType.playlist:
        return 'Playlist';
      case CollectionType.channel:
        return 'Canal';
    }
  }
}

class CollectionModel {
  final String id;
  final String title;
  final String? thumbnail;
  final String? uploader;
  final int? itemCount;
  final List<VideoModel> items;
  final CollectionType type;
  final String? url;

  const CollectionModel({
    required this.id,
    required this.title,
    this.thumbnail,
    this.uploader,
    this.itemCount,
    required this.items,
    required this.type,
    this.url,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'playlist';
    final type = CollectionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => CollectionType.playlist,
    );
    return CollectionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      uploader: json['uploader'],
      itemCount: (json['item_count'] as num?)?.toInt(),
      items: (json['tracks'] as List?)
              ?.map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      type: type,
      url: json['url'],
    );
  }
}

class PlaylistPreview {
  final String id;
  final String title;
  final String? thumbnail;
  final String? uploader;
  final int? itemCount;
  final String url;

  const PlaylistPreview({
    required this.id,
    required this.title,
    this.thumbnail,
    this.uploader,
    this.itemCount,
    required this.url,
  });

  factory PlaylistPreview.fromJson(Map<String, dynamic> json) {
    return PlaylistPreview(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      uploader: json['uploader'],
      itemCount: (json['item_count'] as num?)?.toInt(),
      url: json['url'] ?? '',
    );
  }
}

class ChannelInfo {
  final String id;
  final String name;
  final String? thumbnail;
  final String? url;

  const ChannelInfo({
    required this.id,
    required this.name,
    this.thumbnail,
    this.url,
  });

  factory ChannelInfo.fromJson(Map<String, dynamic> json) {
    return ChannelInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      thumbnail: json['thumbnail'],
      url: json['url'],
    );
  }
}
