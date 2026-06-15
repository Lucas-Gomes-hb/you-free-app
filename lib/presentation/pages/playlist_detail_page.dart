import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../data/models/local_playlist.dart';
import '../../data/models/video_model.dart';
import '../../data/services/playlist_service.dart';
import '../../data/services/download_manager.dart';
import '../../data/repositories/video_repository.dart';
import '../components/mini_player.dart';
import '../components/video_card.dart';
import '../controllers/player_controller.dart';

// Playlist names that hold downloaded tracks — swiping these shows a
// "remove from playlist" vs "delete file from disk" choice.
const _kDownloadPlaylistNames = {'Downloads', 'Downloads Automáticos'};

class PlaylistDetailPage extends StatefulWidget {
  final String playlistId;
  final PlaylistService playlistService;
  final PlayerController playerController;
  final VideoRepository videoRepository;
  final DownloadManager? downloadManager;

  const PlaylistDetailPage({
    Key? key,
    required this.playlistId,
    required this.playlistService,
    required this.playerController,
    required this.videoRepository,
    this.downloadManager,
  }) : super(key: key);

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  // Tracks whether "delete from disk" was chosen for the pending swipe dismiss.
  // Key = videoId, value = true → delete file; false → playlist only.
  final Map<String, bool> _pendingDelete = {};

  bool _isDownloadsPlaylist(LocalPlaylist playlist) =>
      _kDownloadPlaylistNames.contains(playlist.name);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playlistService,
      builder: (context, _) {
        final c = context.c;
        final idx = widget.playlistService.playlists
            .indexWhere((p) => p.id == widget.playlistId);
        final playlist =
            idx >= 0 ? widget.playlistService.playlists[idx] : null;

        if (playlist == null) {
          return Scaffold(
            backgroundColor: c.background,
            appBar: AppBar(title: const Text('Playlist')),
            body: Center(
                child: Text('Playlist não encontrada',
                    style: TextStyle(color: c.textMuted))),
            bottomNavigationBar: MiniPlayer(controller: widget.playerController),
          );
        }

        return Scaffold(
          backgroundColor: c.background,
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
          bottomNavigationBar: MiniPlayer(controller: widget.playerController),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTracksSheet(context, playlist),
            backgroundColor: c.primary,
            mini: true,
            child: Icon(Icons.add_rounded, color: c.onPrimary),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Builder(builder: (context) {
      final c = context.c;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 64, color: c.textMuted),
            const SizedBox(height: 14),
            Text('Nenhuma música adicionada',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Toque + para adicionar músicas',
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ),
      );
    });
  }

  Widget _buildTrackList(BuildContext context, LocalPlaylist playlist) {
    final c = context.c;
    final isDl = _isDownloadsPlaylist(playlist);
    final dm = widget.downloadManager;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      widget.playerController.playFromQueue(playlist.tracks),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Tocar tudo',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
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
                    widget.playerController.playFromQueue(shuffled);
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('Aleatório',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    side: BorderSide(color: c.border),
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
              final canDeleteFile =
                  isDl && dm != null && dm.isDownloaded(video.id);

              return Dismissible(
                key: Key('${playlist.id}_${video.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: c.primary.withValues(alpha: 0.8),
                  child: Icon(Icons.delete_outline_rounded,
                      color: c.onPrimary),
                ),
                confirmDismiss: (_) async {
                  if (!canDeleteFile) {
                    _pendingDelete[video.id] = false;
                    return true;
                  }

                  // Downloads playlist with a downloaded file → ask the user
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: c.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Remover faixa',
                          style: TextStyle(
                              color: c.text,
                              fontWeight: FontWeight.w700)),
                      content: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: c.textMuted, fontSize: 13),
                      ),
                      actionsPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancelar',
                              style: TextStyle(color: c.textMuted)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'playlist'),
                          child: Text('Só da playlist',
                              style: TextStyle(color: c.text)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'disk'),
                          child: Text('Excluir arquivo',
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );

                  if (result == null) return false; // cancelled
                  _pendingDelete[video.id] = (result == 'disk');
                  return true;
                },
                onDismissed: (_) async {
                  final deleteFile = _pendingDelete.remove(video.id) ?? false;
                  if (deleteFile) {
                    // delete() removes the file AND the track from all playlists
                    await dm!.delete(video.id);
                  } else {
                    await widget.playlistService
                        .removeTrack(playlist.id, video.id);
                  }
                },
                child: Observer(
                  builder: (_) => VideoCard(
                    video: video,
                    isCurrentlyPlaying:
                        widget.playerController.isCurrentVideo(video.id),
                    onTap: () => widget.playerController
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
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddTracksSheet(
        playlistId: playlist.id,
        playlistService: widget.playlistService,
        videoRepository: widget.videoRepository,
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final String name;
  const _AppBar({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: c.text,
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: c.text,
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
    final c = context.c;
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
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: c.text, fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar músicas...',
                hintStyle:
                    TextStyle(color: c.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: c.textMuted),
                filled: true,
                fillColor: c.surfaceHigh,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                  color: c.primary,
                  backgroundColor: c.surfaceHigh,
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
                          TextStyle(color: c.textMuted, fontSize: 13),
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
                          style: TextStyle(
                              color: c.text, fontSize: 14),
                        ),
                        subtitle: video.uploader != null
                            ? Text(video.uploader!,
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 12))
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            added
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            color: added
                                ? const Color(0xFF4CAF50)
                                : c.primary,
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
    return Builder(builder: (context) {
      final c = context.c;
      return Container(
        width: 50,
        height: 50,
        color: c.surfaceHigh,
        child: Icon(Icons.music_note_rounded, color: c.textMuted),
      );
    });
  }
}
