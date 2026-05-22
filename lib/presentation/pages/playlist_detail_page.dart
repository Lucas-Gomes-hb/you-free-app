import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/local_playlist.dart';
import '../../data/models/video_model.dart';
import '../../data/services/playlist_service.dart';
import '../../data/repositories/video_repository.dart';
import '../components/mini_player.dart';
import '../components/video_card.dart';
import '../controllers/player_controller.dart';

class PlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  final PlaylistService playlistService;
  final PlayerController playerController;
  final VideoRepository videoRepository;

  const PlaylistDetailPage({
    Key? key,
    required this.playlistId,
    required this.playlistService,
    required this.playerController,
    required this.videoRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playlistService,
      builder: (context, _) {
        final idx = playlistService.playlists.indexWhere((p) => p.id == playlistId);
        final playlist = idx >= 0 ? playlistService.playlists[idx] : null;

        if (playlist == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            appBar: AppBar(title: const Text('Playlist')),
            body: const Center(
                child: Text('Playlist não encontrada',
                    style: TextStyle(color: Colors.grey))),
            bottomNavigationBar: MiniPlayer(controller: playerController),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: SafeArea(
            child: Column(
              children: [
                _AppBar(name: playlist.name),
                Expanded(
                  child: playlist.tracks.isEmpty
                      ? _buildEmpty()
                      : _buildTrackList(context, playlist),
                ),
              ],
            ),
          ),
          bottomNavigationBar: MiniPlayer(controller: playerController),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTracksSheet(context, playlist),
            backgroundColor: const Color(0xFFE8432A),
            mini: true,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 14),
          Text('Nenhuma música adicionada',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Toque + para adicionar músicas',
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTrackList(BuildContext context, LocalPlaylist playlist) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      playerController.playFromQueue(playlist.tracks),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Tocar tudo',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8432A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final shuffled = [...playlist.tracks]..shuffle(Random());
                    playerController.playFromQueue(shuffled);
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('Aleatório',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3A3A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: playlist.tracks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, i) {
              final video = playlist.tracks[i];
              return Dismissible(
                key: Key('${playlist.id}_${video.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: const Color(0xFFE8432A).withValues(alpha: 0.8),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
                ),
                onDismissed: (_) =>
                    playlistService.removeTrack(playlist.id, video.id),
                child: Observer(
                  builder: (_) => VideoCard(
                    video: video,
                    isCurrentlyPlaying:
                        playerController.isCurrentVideo(video.id),
                    onTap: () => playerController
                        .playFromQueue(playlist.tracks.sublist(i)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddTracksSheet(
      BuildContext context, LocalPlaylist playlist) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddTracksSheet(
        playlistId: playlist.id,
        playlistService: playlistService,
        videoRepository: videoRepository,
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final String name;
  const _AppBar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: Colors.white,
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTracksSheet extends StatefulWidget {
  final String playlistId;
  final PlaylistService playlistService;
  final VideoRepository videoRepository;

  const _AddTracksSheet({
    required this.playlistId,
    required this.playlistService,
    required this.videoRepository,
  });

  @override
  State<_AddTracksSheet> createState() => _AddTracksSheetState();
}

class _AddTracksSheetState extends State<_AddTracksSheet> {
  final _searchController = TextEditingController();
  List<VideoModel> _results = [];
  bool _loading = false;
  String? _error;
  final Set<String> _addedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await widget.videoRepository.searchVideos(query.trim());
      setState(() => _results = results);
    } catch (_) {
      setState(() => _error = 'Erro ao buscar. Tente novamente.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar músicas...',
                hintStyle:
                    TextStyle(color: Colors.grey[600], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                  color: Color(0xFFE8432A),
                  backgroundColor: Color(0xFF2A2A2A),
                  minHeight: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.orange, fontSize: 13)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'Busque por nome ou artista',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final video = _results[i];
                      final added = _addedIds.contains(video.id);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: video.thumbnail != null
                              ? CachedNetworkImage(
                                  imageUrl: video.thumbnail!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _thumbPlaceholder(),
                                  errorWidget: (_, __, ___) =>
                                      _thumbPlaceholder(),
                                )
                              : _thumbPlaceholder(),
                        ),
                        title: Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: video.uploader != null
                            ? Text(video.uploader!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12))
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            added
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            color: added
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE8432A),
                          ),
                          onPressed: added
                              ? null
                              : () async {
                                  await widget.playlistService
                                      .addTrack(widget.playlistId, video);
                                  setState(
                                      () => _addedIds.add(video.id));
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: const Color(0xFF2A2A2A),
      child: Icon(Icons.music_note_rounded, color: Colors.grey[700]),
    );
  }
}
