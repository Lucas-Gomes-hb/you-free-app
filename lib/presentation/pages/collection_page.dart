import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../data/models/collection_model.dart';
import '../components/mini_player.dart';
import '../components/video_card.dart';
import '../controllers/player_controller.dart';

class CollectionPage extends StatelessWidget {
  final CollectionModel collection;
  final PlayerController playerController;

  const CollectionPage({
    Key? key,
    required this.collection,
    required this.playerController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final thumb = collection.thumbnail;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient blurred background from collection cover
          if (thumb != null) ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF0A0A0A)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF0A0A0A)),
              ),
            ),
            Container(color: Colors.black.withValues(alpha: 0.82)),
          ] else
            Container(color: const Color(0xFF0A0A0A)),
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(child: _buildHeader(context)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Divider(color: Color(0xFF2A2A2A), height: 1),
                ),
              ),
              collection.items.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmpty())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = collection.items[index];
                          return Observer(
                            builder: (_) => VideoCard(
                              video: video,
                              isCurrentlyPlaying:
                                  playerController.isCurrentVideo(video.id),
                              onTap: () => playerController.loadVideo(video),
                            ),
                          );
                        },
                        childCount: collection.items.length,
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: MiniPlayer(controller: playerController),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: Colors.white,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        collection.type.label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCover(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeBadge(type: collection.type),
                    const SizedBox(height: 8),
                    Text(
                      collection.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (collection.uploader != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        collection.uploader!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${collection.items.length} ${collection.type == CollectionType.channel ? 'vídeos' : 'faixas'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (collection.items.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => playerController.playFromQueue(collection.items),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Tocar tudo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8432A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    final isChannel = collection.type == CollectionType.channel;
    const size = 120.0;

    if (isChannel) {
      return ClipOval(
        child: _coverImage(size, size),
      );
    }

    return Stack(
      children: [
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          top: 3,
          left: 3,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _coverImage(size, size),
        ),
      ],
    );
  }

  Widget _coverImage(double width, double height) {
    if (collection.thumbnail != null) {
      return CachedNetworkImage(
        imageUrl: collection.thumbnail!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _coverPlaceholder(width, height),
        errorWidget: (_, __, ___) => _coverPlaceholder(width, height),
      );
    }
    return _coverPlaceholder(width, height);
  }

  Widget _coverPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2A2A2A),
      child: Icon(
        collection.type == CollectionType.channel
            ? Icons.person_rounded
            : Icons.library_music_rounded,
        color: const Color(0xFF555555),
        size: width * 0.4,
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.queue_music_rounded, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              'Nenhum item encontrado',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final CollectionType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _badgeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_badgeIcon, color: _badgeColor, size: 12),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              color: _badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color get _badgeColor {
    switch (type) {
      case CollectionType.album:
        return const Color(0xFFFF9800);
      case CollectionType.playlist:
        return const Color(0xFF4FC3F7);
      case CollectionType.channel:
        return const Color(0xFFF5C030);
    }
  }

  IconData get _badgeIcon {
    switch (type) {
      case CollectionType.album:
        return Icons.album_rounded;
      case CollectionType.playlist:
        return Icons.queue_music_rounded;
      case CollectionType.channel:
        return Icons.subscriptions_rounded;
    }
  }
}
