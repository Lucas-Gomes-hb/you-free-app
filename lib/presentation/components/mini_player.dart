import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../controllers/player_controller.dart';
import '../controllers/video_session_controller.dart';
import '../widgets/video_player_surface.dart';

/// Bottom bar for whatever is playing: the video session when one is open,
/// the audio player otherwise. Tapping it goes back to the screen that owns
/// that playback — the Watch page for a video, the music player for a track.
class MiniPlayer extends StatelessWidget {
  final PlayerController controller;

  /// Null on the music-only pages pushed outside the shell, which never host
  /// a video.
  final VideoSessionController? videoSession;

  const MiniPlayer({
    Key? key,
    required this.controller,
    this.videoSession,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final session = videoSession;
    if (session == null) return _AudioMiniPlayer(controller: controller);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.isActive
          ? _VideoMiniPlayer(session: session)
          : _AudioMiniPlayer(controller: controller),
    );
  }
}

class _AudioMiniPlayer extends StatelessWidget {
  final PlayerController controller;

  const _AudioMiniPlayer({required this.controller});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Observer(builder: (_) {
      final video = controller.currentVideo;
      if (video == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => context.push('/player', extra: video),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: c.border, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Observer(builder: (_) => LinearProgressIndicator(
                value: controller.progress.clamp(0.0, 1.0),
                backgroundColor: c.surfaceHigh,
                color: c.primary,
                minHeight: 2,
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _Thumbnail(url: video.thumbnail),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Observer(builder: (_) {
                            final dur = controller.duration;
                            final pos = controller.position;
                            if (dur == Duration.zero) {
                              return Text(
                                video.uploader ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.textMuted),
                              );
                            }
                            return Row(
                              children: [
                                if (video.uploader != null)
                                  Flexible(
                                    child: Text(
                                      video.uploader!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: c.textMuted),
                                    ),
                                  ),
                                Text(
                                  '  ${_fmt(pos)} / ${_fmt(dur)}',
                                  style: TextStyle(fontSize: 11, color: c.textMuted),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    Observer(builder: (_) {
                      if (controller.isLoading) {
                        return SizedBox(
                          width: 48, height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                            ),
                          ),
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: c.text,
                              size: 30,
                            ),
                            onPressed: controller.togglePlayPause,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next_rounded, color: c.text, size: 26),
                            onPressed: controller.skipToNext,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;

  /// Fills its box instead of drawing the square cover art.
  final bool wide;

  const _Thumbnail({this.url, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final size = wide ? null : 48.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 0 : 6),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: size ?? double.infinity,
              height: size ?? double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        width: 48, height: 48,
        color: c.surfaceHigh,
        child: Icon(Icons.music_note_rounded, color: c.textMuted, size: 22),
      );
    });
  }
}

class _VideoMiniPlayer extends StatelessWidget {
  final VideoSessionController session;

  const _VideoMiniPlayer({required this.session});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final video = session.current!;
    final playback = session.playback;

    return GestureDetector(
      onTap: () => context.push('/watch', extra: video),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: ListenableBuilder(
          listenable: playback,
          builder: (context, _) {
            final dur = playback.duration.inMilliseconds;
            final progress =
                dur <= 0 ? 0.0 : playback.position.inMilliseconds / dur;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: c.surfaceHigh,
                  color: const Color(0xFFFF0033),
                  minHeight: 2,
                ),
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 107,
                        height: 60,
                        child: ColoredBox(
                          color: Colors.black,
                          // While the Watch page is open it draws the picture;
                          // the mini player only goes live once it is gone.
                          child: session.isWatchPageOpen
                              ? _Thumbnail(url: video.thumbnail, wide: true)
                              : VideoPlayerSurface(
                                  controller: playback,
                                  onToggleFullscreen: () {},
                                  showControls: false,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              video.uploader ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          playback.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: c.text,
                          size: 28,
                        ),
                        onPressed: session.togglePlayPause,
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: c.text, size: 24),
                        onPressed: session.close,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
