import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../controllers/player_controller.dart';

class MiniPlayer extends StatelessWidget {
  final PlayerController controller;

  const MiniPlayer({Key? key, required this.controller}) : super(key: key);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final video = controller.currentVideo;
      if (video == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => context.push('/player', extra: video),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            border: const Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Observer(builder: (_) => LinearProgressIndicator(
                value: controller.progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF2A2A2A),
                color: const Color(0xFFE8432A),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ),
                                Text(
                                  '  ${_fmt(pos)} / ${_fmt(dur)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    Observer(builder: (_) {
                      if (controller.isLoading) {
                        return const SizedBox(
                          width: 48, height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8432A)),
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
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: controller.togglePlayPause,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
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
  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: 48, height: 48, fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48, height: 48,
      color: const Color(0xFF2A2A2A),
      child: Icon(Icons.music_note_rounded, color: Colors.grey[700], size: 22),
    );
  }
}
