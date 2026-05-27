import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/local_playlist.dart';
import '../../data/services/playlist_service.dart';
import '../../data/services/download_manager.dart';
import '../../data/repositories/video_repository.dart';
import '../controllers/player_controller.dart';

class PlaylistsPage extends StatelessWidget {
  final PlaylistService playlistService;
  final PlayerController playerController;
  final VideoRepository videoRepository;
  final DownloadManager downloadManager;

  const PlaylistsPage({
    Key? key,
    required this.playlistService,
    required this.playerController,
    required this.videoRepository,
    required this.downloadManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: ListenableBuilder(
                listenable: playlistService,
                builder: (context, _) {
                  final playlists = playlistService.playlists;
                  if (playlists.isEmpty) return _buildEmpty();
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 86, color: Color(0xFF1E1E1E)),
                    itemBuilder: (context, i) {
                      final pl = playlists[i];
                      return _PlaylistTile(
                        playlist: pl,
                        onTap: () => _openDetail(context, pl),
                        onDelete: () => _deletePlaylist(context, pl),
                        onRename: () => _renamePlaylist(context, pl),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlaylist(context),
        backgroundColor: const Color(0xFFE8432A),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Playlists',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5),
            ),
          ),
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: Colors.grey[600], size: 22),
            tooltip: 'Importar de URL',
            onPressed: () => _importFromUrl(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music_rounded, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 14),
          Text(
            'Nenhuma playlist criada',
            style: TextStyle(
                color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque + para criar ou importe de uma URL',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, LocalPlaylist playlist) {
    context.push('/playlist-detail', extra: {
      'playlistId': playlist.id,
      'playlistService': playlistService,
      'playerController': playerController,
      'videoRepository': videoRepository,
      'downloadManager': downloadManager,
    });
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final name = await _showNameDialog(context, 'Nova playlist', '');
    if (name != null && name.trim().isNotEmpty) {
      await playlistService.create(name.trim());
    }
  }

  Future<void> _renamePlaylist(BuildContext context, LocalPlaylist playlist) async {
    final name = await _showNameDialog(context, 'Renomear', playlist.name);
    if (name != null && name.trim().isNotEmpty) {
      await playlistService.rename(playlist.id, name.trim());
    }
  }

  Future<void> _deletePlaylist(BuildContext context, LocalPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Deletar playlist',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Deletar "${playlist.name}"?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar',
                style: TextStyle(color: Color(0xFFE8432A))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await playlistService.delete(playlist.id);
    }
  }

  Future<void> _importFromUrl(BuildContext context) async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool loading = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Importar playlist',
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'URL do YouTube ou Spotify...',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nome da playlist (opcional)',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                      color: Color(0xFFE8432A),
                      backgroundColor: Color(0xFF2A2A2A)),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        final url = urlController.text.trim();
                        if (url.isEmpty) return;
                        setStateDialog(() {
                          loading = true;
                          error = null;
                        });
                        try {
                          final collection =
                              await videoRepository.getCollection(url);
                          final name = nameController.text.trim().isNotEmpty
                              ? nameController.text.trim()
                              : collection.title;
                          final playlist = await playlistService.create(name);
                          await playlistService.addTracks(
                              playlist.id, collection.items);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          setStateDialog(() {
                            loading = false;
                            error = 'Não foi possível importar. Verifique a URL.';
                          });
                        }
                      },
                child: const Text('Importar',
                    style: TextStyle(color: Color(0xFFE8432A))),
              ),
            ],
          ),
        );
      },
    );

    urlController.dispose();
    nameController.dispose();
  }

  Future<String?> _showNameDialog(
      BuildContext context, String title, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome da playlist',
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child:
                const Text('OK', style: TextStyle(color: Color(0xFFE8432A))),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _PlaylistTile extends StatelessWidget {
  final LocalPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFE8432A).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: playlist.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: playlist.thumbnail!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
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
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.tracks.length} faixa${playlist.tracks.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: Colors.grey[600], size: 20),
              color: const Color(0xFF1A1A1A),
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.white70),
                    SizedBox(width: 10),
                    Text('Renomear',
                        style: TextStyle(color: Colors.white)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFE8432A)),
                    SizedBox(width: 10),
                    Text('Deletar',
                        style: TextStyle(color: Color(0xFFE8432A))),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFF2A2A2A),
      child: Icon(Icons.queue_music_rounded, color: Colors.grey[700], size: 26),
    );
  }
}
