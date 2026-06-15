import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/models/collection_model.dart';

class ChannelCard extends StatelessWidget {
  final ChannelInfo channel;
  final VoidCallback onTap;
  final bool isLoading;

  const ChannelCard({
    Key? key,
    required this.channel,
    required this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: isLoading ? null : onTap,
      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _Avatar(url: channel.thumbnail),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Canal',
                          style: TextStyle(
                            color: c.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: c.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: 56,
              height: 56,
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
        width: 56,
        height: 56,
        color: c.surfaceHigh,
        child: Icon(Icons.person_rounded, color: c.textMuted, size: 28),
      );
    });
  }
}
