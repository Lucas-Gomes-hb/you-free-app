import 'package:flutter_test/flutter_test.dart';
import 'package:youfree/data/models/video_model.dart';
import 'package:youfree/data/services/remote_content_source.dart';

/// The API answers a video stream with a quality ladder next to the playable
/// URL. These cover the split that decides what the player is allowed to offer:
/// DASH rungs have no audio of their own, progressive rungs do.
void main() {
  group('VideoResolution', () {
    test('derives the label from the height when the API omits it', () {
      final r = VideoResolution.fromJson({'height': 1080, 'url': 'u'});
      expect(r.label, '1080p');
    });

    test('keeps the label the API sent', () {
      final r = VideoResolution.fromJson({'height': 1080, 'label': 'Full HD', 'url': 'u'});
      expect(r.label, 'Full HD');
    });

    test('falls back to auto when there is no height to name it after', () {
      final r = VideoResolution.fromJson({'url': 'u'});
      expect(r.label, 'auto');
      expect(r.height, isNull);
    });
  });

  group('StreamInfo quality ladder', () {
    test('parses the ladder in the order the API sent it, best first', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_url': 'https://cdn/manifest.mpd',
        'video_format': 'dash',
        'video_resolutions': [
          {'label': '2160p', 'height': 2160, 'url': 'u4k', 'is_video_only': true},
          {'label': '1080p', 'height': 1080, 'url': 'u1080', 'is_video_only': true},
        ],
      });

      expect(info.videoResolutions.map((r) => r.label), ['2160p', '1080p']);
      expect(info.bestResolution?.height, 2160);
    });

    test('drops ladder entries with no url', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_resolutions': [
          {'label': '1080p', 'height': 1080, 'url': ''},
          {'label': '720p', 'height': 720, 'url': 'u720'},
        ],
      });

      expect(info.videoResolutions.length, 1);
      expect(info.videoResolutions.single.label, '720p');
    });

    test('a DASH ladder is not switchable, since each rung has no audio', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_format': 'dash',
        'video_resolutions': [
          {'label': '1080p', 'height': 1080, 'url': 'u1', 'is_video_only': true},
          {'label': '720p', 'height': 720, 'url': 'u2', 'is_video_only': true},
        ],
      });

      expect(info.switchableResolutions, isEmpty);
      expect(info.bestResolution, isNotNull);
    });

    test('a progressive ladder is switchable rung by rung', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_format': 'progressive',
        'video_resolutions': [
          {'label': '1080p', 'height': 1080, 'url': 'u1', 'is_video_only': false},
          {'label': '720p', 'height': 720, 'url': 'u2', 'is_video_only': false},
          {'label': '360p', 'height': 360, 'url': 'u3', 'is_video_only': false},
        ],
      });

      expect(info.switchableResolutions.map((r) => r.label),
          ['1080p', '720p', '360p']);
    });

    test('a missing ladder leaves the source playable but not switchable', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_url': 'https://cdn/master.m3u8',
        'video_format': 'hls',
      });

      expect(info.videoResolutions, isEmpty);
      expect(info.switchableResolutions, isEmpty);
      expect(info.bestResolution, isNull);
      expect(info.videoUrl, 'https://cdn/master.m3u8');
    });

    test('is_video_only defaults to true, which is the safe assumption', () {
      final info = StreamInfo.fromJson({
        'title': 't',
        'video_resolutions': [
          {'label': '1080p', 'height': 1080, 'url': 'u1'},
        ],
      });

      expect(info.videoResolutions.single.isVideoOnly, isTrue);
    });
  });

  group('manifest URL resolution', () {
    StreamInfo dash(Map<String, dynamic> extra) => StreamInfo.fromJson({
          'title': 't',
          'video_format': 'dash',
          ...extra,
        });

    test('a root-relative manifest path is joined onto the API base', () {
      final info = dash({'video_url': '/dash/dQw4w9WgXcQ.mpd'});
      expect(
        withAbsoluteStreamUrl('http://127.0.0.1:8000', info).videoUrl,
        'http://127.0.0.1:8000/dash/dQw4w9WgXcQ.mpd',
      );
    });

    test('a trailing slash on the base does not double up', () {
      final info = dash({'video_url': '/dash/abc.mpd'});
      expect(
        withAbsoluteStreamUrl('http://10.0.0.5:8000/', info).videoUrl,
        'http://10.0.0.5:8000/dash/abc.mpd',
      );
    });

    test('an absolute CDN URL is left exactly as sent', () {
      final info = dash({
        'video_url': 'https://rr1---sn-x.googlevideo.com/videoplayback?expire=1',
      });
      expect(
        withAbsoluteStreamUrl('http://127.0.0.1:8000', info).videoUrl,
        'https://rr1---sn-x.googlevideo.com/videoplayback?expire=1',
      );
    });

    test('resolution is preserved, so the quality ladder survives the join', () {
      final info = dash({
        'video_url': '/dash/x.mpd',
        'video_resolutions': [
          {'label': '2160p', 'height': 2160, 'url': 'u4k', 'is_video_only': true},
          {'label': '1080p', 'height': 1080, 'url': 'u1080', 'is_video_only': true},
        ],
      });
      final resolved = withAbsoluteStreamUrl('http://127.0.0.1:8000', info);
      expect(resolved.videoFormat, 'dash');
      expect(resolved.videoResolutions.map((r) => r.label), ['2160p', '1080p']);
      expect(resolved.videoResolutions.every((r) => r.isVideoOnly), isTrue);
    });

    test('a null video URL is not turned into a bare base URL', () {
      final info = dash({});
      expect(withAbsoluteStreamUrl('http://127.0.0.1:8000', info).videoUrl, isNull);
    });
  });
}
