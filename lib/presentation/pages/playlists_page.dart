import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
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
                    separatorBuilder: (_, __) => Divider(
                        height: 1, indent: 86, color: context.c.border),
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
        backgroundColor: context.c.primary,
        child: Icon(Icons.add_rounded, color: context.c.onPrimary),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Playlists',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  letterSpacing: -0.5),
            ),
          ),
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: c.textMuted, size: 22),
            tooltip: 'Importar de URL',
            onPressed: () => _importFromUrl(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Builder(builder: (context) {
      final c = context.c;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music_rounded, size: 64, color: c.textMuted),
            const SizedBox(height: 14),
            Text(
              'Nenhuma playlist criada',
              style: TextStyle(
                  color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque + para criar ou importe de uma URL',
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    });
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
    final c = context.c;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Deletar playlist',
            style: TextStyle(color: c.text)),
        content: Text(
          'Deletar "${playlist.name}"?',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancelar', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Deletar',
                style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await playlistService.delete(playlist.id);
    }
  }

  Future<void> _importFromUrl(BuildContext context) async {
    final c = context.c;
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
            backgroundColor: c.surface,
            title: Text('Importar playlist',
                style: TextStyle(color: c.text)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'URL do YouTube ou Spotify...',
                    hintStyle:
                        TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Nome da playlist (opcional)',
                    hintStyle:
                        TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                      color: c.primary,
                      backgroundColor: c.surfaceHigh),
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
                    style: TextStyle(color: c.textMuted)),
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
                child: Text('Importar',
                    style: TextStyle(color: c.primary)),
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
    final c = context.c;
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(title, style: TextStyle(color: c.text)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: c.text),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome da playlist',
            hintStyle: TextStyle(color: c.textMuted),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child:
                Text('OK', style: TextStyle(color: c.primary)),
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
    final c = context.c;
    return InkWell(
      onTap: onTap,
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
                    style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.tracks.length} faixa${playlist.tracks.length == 1 ? '' : 's'}',
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: c.textMuted, size: 20),
              color: c.surfaceHigh,
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: c.text),
                    const SizedBox(width: 10),
                    Text('Renomear', style: TextStyle(color: c.text)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: c.primary),
                    const SizedBox(width: 10),
                    Text('Deletar', style: TextStyle(color: c.primary)),
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
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        width: 56,
        height: 56,
        color: c.surfaceHigh,
        child: Icon(Icons.queue_music_rounded, color: c.textMuted, size: 26),
      );
    });
  }
}
