import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../app/theme.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/video_model.dart';
import '../controllers/player_controller.dart';

/// A single entry in the search suggestion dropdown, tagged so the UI can
/// distinguish local history entries from remote YouTube completions.
class SuggestionItem {
  final String text;
  final bool isHistory;
  const SuggestionItem(this.text, this.isHistory);
}

/// Scaffold shared by the music home and search tabs: renders the ambient
/// blurred artwork of whatever is currently playing, then the page content.
class AmbientScaffold extends StatelessWidget {
  final Widget child;
  final PlayerController playerController;

  const AmbientScaffold({
    super.key,
    required this.child,
    required this.playerController,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Observer(builder: (_) {
        final thumb = playerController.currentVideo?.thumbnail;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null) ...[
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: c.background),
                  errorWidget: (_, __, ___) => Container(color: c.background),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.82)),
            ] else
              Container(color: c.background),
            SafeArea(child: child),
          ],
        );
      }),
    );
  }
}

/// Pill-shaped single-select filter used for the Músicas/Artistas/Álbums row.
class MusicFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MusicFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.onPrimary : c.textMuted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Dense grid tile that starts playback on tap, used by the home feed rows.
class QuickPlayTile extends StatelessWidget {
  final VideoModel video;
  final bool isPlaying;
  final VoidCallback onTap;

  const QuickPlayTile({
    super.key,
    required this.video,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying
              ? c.primary.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: video.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnail!,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      placeholder: (_, __) => _artPlaceholder(),
                      errorWidget: (_, __, ___) => _artPlaceholder(),
                    )
                  : _artPlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? c.secondary : c.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (video.uploader != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        video.uploader!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textMuted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isPlaying)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.equalizer_rounded, color: c.secondary, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder() {
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        color: c.surfaceHigh,
        child: Icon(Icons.music_note_rounded, color: c.textMuted, size: 20),
      );
    });
  }
}

/// List row for playlist/album search results.
class MusicPlaylistTile extends StatelessWidget {
  final PlaylistPreview playlist;
  final VoidCallback onTap;
  final bool isLoading;

  const MusicPlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: isLoading ? null : onTap,
      splashColor: c.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: playlist.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: playlist.thumbnail!,
                      width: 56, height: 56, fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(4)),
                        child: Text('Playlist',
                            style: TextStyle(color: c.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if (playlist.uploader != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(playlist.uploader!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textMuted, fontSize: 12)),
                        ),
                      ],
                      if (playlist.itemCount != null) ...[
                        const SizedBox(width: 6),
                        Text('${playlist.itemCount} faixas',
                            style: TextStyle(color: c.textMuted, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: c.primary, strokeWidth: 2))
                : Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        width: 56, height: 56, color: c.surfaceHigh,
        child: Icon(Icons.queue_music_rounded, color: c.textMuted, size: 26),
      );
    });
  }
}
