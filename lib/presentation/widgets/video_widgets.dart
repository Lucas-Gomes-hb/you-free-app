import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/video_model.dart';

/// A video as a wide card, the shape YouTube itself uses for a watch result.
///
/// The channel name, view count and age form one meta line, and anything the
/// parser could not resolve is dropped rather than shown as a gap.
class VideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback? onTap;

  const VideoCard({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meta = _metaLine();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              // A Row hands non-flex children unbounded main-axis constraints,
              // so the ratio has to be anchored to a width or it cannot resolve
              // a height inside a vertically scrolling list.
              width: 156,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumb(c),
                      if (video.duration != null)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.durationFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (video.uploader != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      video.uploader!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                  ],
                  if (_visibleBadges.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _badges(c),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(AppPalette c) {
    final url = video.thumbnail;
    if (url == null) {
      return Container(color: c.surfaceHigh);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: c.surfaceHigh),
      errorWidget: (_, __, ___) => Container(color: c.surfaceHigh),
    );
  }

  /// Refined searches come back with the length as a badge too, which would
  /// print it a second time under the one already on the thumbnail.
  static final _durationBadge = RegExp(r'^\d+(:\d{2})+$');

  List<String> get _visibleBadges => video.badges
      .where((b) => !_durationBadge.hasMatch(b.trim()))
      .take(2)
      .toList();

  Widget _badges(AppPalette c) {
    return Wrap(
      spacing: 5,
      children: [
        for (final badge in _visibleBadges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _metaLine() {
    final parts = <String>[];
    final views = VideoModel.formatViewCount(video.viewCount);
    if (views.isNotEmpty) parts.add('$views visualizações');
    if (video.publishedText != null && video.publishedText!.isNotEmpty) {
      parts.add(video.publishedText!);
    }
    return parts.join(' · ');
  }
}

/// A single comment, with its replies counted but not expanded: the core watch
/// experience shows the thread at one level, matching the scope agreed for
/// this phase.
class CommentTile extends StatelessWidget {
  final VideoComment comment;

  const CommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final likes = VideoModel.formatViewCount(comment.likeCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundImage: comment.authorThumbnail != null
                ? NetworkImage(comment.authorThumbnail!)
                : null,
            backgroundColor: c.surfaceHigh,
            child: comment.authorThumbnail == null
                ? Text(
                    _initial(comment.authorName),
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName ?? 'Anônimo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.isPinned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin_rounded, size: 12, color: c.primary),
                    ],
                    if (comment.isCreatorHearted) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.favorite_rounded,
                          size: 12, color: c.secondary),
                    ],
                    const SizedBox(width: 8),
                    if (comment.publishedText != null)
                      Text(
                        comment.publishedText!,
                        style: TextStyle(color: c.textMuted, fontSize: 11.5),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                if (likes.isNotEmpty || comment.replyCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (likes.isNotEmpty)
                        Text(
                          '👍 $likes',
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                      if (comment.replyCount > 0) ...[
                        if (likes.isNotEmpty) const SizedBox(width: 14),
                        Text(
                          '${comment.replyCount} respostas',
                          style: TextStyle(color: c.textMuted, fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
