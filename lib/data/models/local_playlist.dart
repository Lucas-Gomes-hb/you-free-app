import 'video_model.dart';

class LocalPlaylist {
  final String id;
  String name;
  List<VideoModel> tracks;

  LocalPlaylist({required this.id, required this.name, required this.tracks});

  String? get thumbnail => tracks.isNotEmpty ? tracks.first.thumbnail : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((v) => v.toJson()).toList(),
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) => LocalPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        tracks: (json['tracks'] as List?)
                ?.map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
