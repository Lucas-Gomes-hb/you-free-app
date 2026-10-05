import 'package:flutter_test/flutter_test.dart';
import 'package:youfree/data/models/video_model.dart';

void main() {
  group('VideoModel playedAsVideo', () {
    VideoModel sample() => VideoModel(
          id: 'abc123',
          title: 'Song',
          url: 'https://youtu.be/abc123',
          duration: 213,
        );

    test('defaults to false', () {
      expect(sample().playedAsVideo, isFalse);
    });

    test('survives a json round trip when set', () {
      final marked = sample().copyWith(playedAsVideo: true);
      final restored = VideoModel.fromJson(marked.toJson());
      expect(restored.playedAsVideo, isTrue);
      expect(restored.id, 'abc123');
    });

    test('an unmarked entry stays unmarked', () {
      final restored = VideoModel.fromJson(sample().toJson());
      expect(restored.playedAsVideo, isFalse);
    });

    test('a history written before the flag existed reads as audio', () {
      // Old entries have no key at all; they must not be guessed into videos.
      final restored = VideoModel.fromJson(sample().toJson()..remove('played_as_video'));
      expect(restored.playedAsVideo, isFalse);
    });

    test('copyWith keeps every other field', () {
      final marked = sample().copyWith(playedAsVideo: true);
      expect(marked.title, 'Song');
      expect(marked.duration, 213);
      expect(marked.url, 'https://youtu.be/abc123');
    });
  });
}