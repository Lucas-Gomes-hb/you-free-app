import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/models/video_model.dart';

class VideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final bool isCurrentlyPlaying;

  const VideoCard({
    Key? key,
    required this.video,
    required this.onTap,
    this.isCurrentlyPlaying = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            _Thumbnail(url: video.thumbnail),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentlyPlaying ? c.primary : c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (video.uploader != null) ...[
                        Flexible(
                          child: Text(
                            video.uploader!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                        ),
                        Text(' · ', style: TextStyle(color: c.textMuted, fontSize: 12)),
                      ],
                      Text(
                        video.durationFormatted,
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCurrentlyPlaying ? Icons.equalizer_rounded : Icons.more_vert_rounded,
              color: isCurrentlyPlaying ? c.primary : c.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;

  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          if (url != null)
            CachedNetworkImage(
              imageUrl: url!,
              width: 112,
              height: 64,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        width: 112,
        height: 64,
        color: c.surfaceHigh,
        child: Icon(Icons.music_note_rounded, color: c.textMuted, size: 28),
      );
    });
  }
}
