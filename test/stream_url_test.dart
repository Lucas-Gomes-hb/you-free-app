import 'package:flutter_test/flutter_test.dart';
import 'package:youfree/data/models/video_model.dart';
import 'package:youfree/data/services/remote_content_source.dart';

void main() {
  StreamInfo info({String? videoUrl, String? hlsUrl}) => StreamInfo(
        title: 'A video',
        formats: const [],
        videoUrl: videoUrl,
        hlsUrl: hlsUrl,
        videoFormat: videoUrl != null ? 'dash' : null,
      );

  group('withAbsoluteStreamUrl', () {
    const base = 'http://localhost:8000';

    test('joins the DASH path', () {
      final out = withAbsoluteStreamUrl(base, info(videoUrl: '/dash/abc.mpd'));
      expect(out.videoUrl, '$base/dash/abc.mpd');
    });

    test('keeps the HLS path, which is what playback prefers', () {
      // Rebuilding StreamInfo without hlsUrl silently sent the player back to
      // the 2 GB DASH rung, which is the freeze this whole path exists to fix.
      final out = withAbsoluteStreamUrl(
          base, info(videoUrl: '/dash/abc.mpd', hlsUrl: '/hls/abc.m3u8'));
      expect(out.hlsUrl, '$base/hls/abc.m3u8');
    });

    test('preserves the other fields', () {
      final out = withAbsoluteStreamUrl(
        base,
        StreamInfo(
          title: 'A video',
          duration: 8100,
          uploader: 'Someone',
          formats: const [],
          videoUrl: '/dash/abc.mpd',
          videoFormat: 'dash',
          hlsUrl: '/hls/abc.m3u8',
          videoResolutions: [
            const VideoResolution(
                label: '720p', height: 720, url: '/dash/abc.mpd?height=720'),
          ],
        ),
      );
      expect(out.title, 'A video');
      expect(out.duration, 8100);
      expect(out.uploader, 'Someone');
      expect(out.videoFormat, 'dash');
      expect(out.videoResolutions.single.height, 720);
    });

    test('leaves an absolute URL untouched', () {
      const url = 'https://rr1---sn-abc.googlevideo.com/videoplayback';
      final out = withAbsoluteStreamUrl(base, info(videoUrl: url));
      expect(out.videoUrl, url);
      expect(identical(out, out), isTrue);
    });

    test('tolerates a trailing slash on the base URL', () {
      final out = withAbsoluteStreamUrl(
          '$base/', info(videoUrl: '/dash/abc.mpd', hlsUrl: '/hls/abc.m3u8'));
      expect(out.videoUrl, '$base/dash/abc.mpd');
      expect(out.hlsUrl, '$base/hls/abc.m3u8');
    });
  });
}