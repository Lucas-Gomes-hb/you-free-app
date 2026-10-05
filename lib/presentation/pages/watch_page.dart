import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';
import '../controllers/video_playback_controller.dart';
import '../controllers/video_session_controller.dart';
import '../controllers/video_watch_controller.dart';
import '../widgets/video_player_surface.dart';
import '../widgets/video_widgets.dart';

/// Watch page for one video.
///
/// The header, the "up next" rail and the comment thread are separate sections
/// that load independently, so a slow comment section never delays playback.
/// Playback itself belongs to [VideoSessionController]: leaving the page only
/// minimizes the video, it does not stop it.
class WatchPage extends StatefulWidget {
  final VideoModel video;
  final VideoSessionController session;
  final VoidCallback? onBack;

  const WatchPage({
    super.key,
    required this.video,
    required this.session,
    this.onBack,
  });

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final _commentScrollController = ScrollController();

  VideoSessionController get _session => widget.session;
  VideoPlaybackController get _playback => _session.playback;
  VideoWatchController get _controller => _session.watch!;
  VideoModel get _current => _session.current ?? widget.video;

  @override
  void initState() {
    super.initState();
    _commentScrollController.addListener(_onCommentScroll);
    _session.attachWatchPage();
    _session.open(widget.video);
  }

  @override
  void dispose() {
    _commentScrollController.dispose();
    _session.detachWatchPage();
    super.dispose();
  }

  void _onCommentScroll() {
    if (_session.watch == null) return;
    final position = _commentScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _controller.loadMoreComments();
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _FullscreenHost(
          playback: _playback,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In Picture-in-Picture the whole activity is the small window, so only
    // the picture is drawn: no page, no controls.
    return ValueListenableBuilder<bool>(
      valueListenable: _session.pipMode,
      builder: (context, inPip, _) {
        if (inPip) {
          return ColoredBox(
            color: Colors.black,
            child: VideoPlayerSurface(
              controller: _playback,
              onToggleFullscreen: () {},
              showControls: false,
            ),
          );
        }
        return ListenableBuilder(
          listenable: _session,
          builder: (context, _) => _buildPage(),
        );
      },
    );
  }

  Widget _buildPage() {
    final c = context.c;
    final hasWatch = _session.watch != null;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: CustomScrollView(
              controller: _commentScrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildPlayer()),
                if (hasWatch) ...[
                  SliverToBoxAdapter(child: _buildTitle()),
                  SliverToBoxAdapter(child: _buildStats()),
                  SliverToBoxAdapter(child: _buildDescription()),
                  SliverToBoxAdapter(child: _buildRelatedHeader()),
                  _relatedSection(),
                  SliverToBoxAdapter(child: _buildCommentsHeader()),
                  _commentsSection(),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final c = context.c;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: c.text),
              onPressed: widget.onBack ?? () => context.pop(),
            ),
            Expanded(
              child: Text(
                'Assistindo',
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_horiz_rounded, color: c.textMuted),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: VideoPlayerSurface(
          controller: _playback,
          onToggleFullscreen: _openFullscreen,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final c = context.c;
    return Observer(builder: (_) {
      final details = _controller.details;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details?.title ?? _current.title,
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            _buildChannel(),
          ],
        ),
      );
    });
  }

  Widget _buildChannel() {
    final c = context.c;
    return Observer(builder: (_) {
      final details = _controller.details;
      final avatar = details?.channelThumbnail;

      return Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                avatar != null ? NetworkImage(avatar) : null,
            backgroundColor: c.surfaceHigh,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details?.channelName ?? _current.uploader ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (details?.subscriberCountText != null)
                  Text(
                    details!.subscriberCountText!,
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Inscrever-se'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.surfaceHigh,
              foregroundColor: c.text,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStats() {
    final c = context.c;
    return Observer(builder: (_) {
      final details = _controller.details;
      final parts = <String>[];
      final views = VideoModel.formatViewCount(details?.viewCount);
      if (views.isNotEmpty) parts.add('$views visualizações');
      if (details?.publishedText != null) parts.add(details!.publishedText!);
      if (parts.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          parts.join(' · '),
          style: TextStyle(color: c.textMuted, fontSize: 13),
        ),
      );
    });
  }

  Widget _buildDescription() {
    final c = context.c;
    return Observer(builder: (_) {
      final details = _controller.details;
      if (_controller.isLoadingDetails) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SizedBox(
            height: 46,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        );
      }
      final description = details?.description;
      if (description == null || description.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.text, fontSize: 13, height: 1.4),
              ),
              if (description.length > 220) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showFullDescription(context, description),
                  child: Text(
                    'Mostrar mais',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  void _showFullDescription(BuildContext context, String description) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Text(
            description,
            style: TextStyle(color: c.text, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedHeader() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 6),
      child: Text(
        'Próximos vídeos',
        style: TextStyle(
          color: c.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _relatedSection() {
    return Observer(builder: (_) {
      if (_controller.isLoadingRelated && _controller.related.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (_controller.relatedError != null && _controller.related.isEmpty) {
        return SliverToBoxAdapter(
          child: _sectionMessage(
            _controller.relatedError!,
            _controller.loadRelated,
          ),
        );
      }
      if (_controller.related.isEmpty) return const SliverToBoxAdapter();

      return SliverList.builder(
        itemCount: _controller.related.length,
        itemBuilder: (context, i) {
          final video = _controller.related[i];
          return VideoCard(
            video: video,
            onTap: () => _openRelated(video),
          );
        },
      );
    });
  }

  /// Related items replace this page in place rather than pushing a new route,
  /// so backing out of a chain of recommendations lands on the first video.
  ///
  /// The player is reloaded for the new id, not reused: the stream URL is
  /// signed per video, so keeping the old surface would either freeze on the
  /// previous frame or die mid-playback.
  void _openRelated(VideoModel video) {
    _commentScrollController.jumpTo(0);
    _session.open(video);
  }

  Widget _buildCommentsHeader() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 4),
      child: Row(
        children: [
          Text(
            'Comentários',
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          // Ordering is a re-fetch, not a re-sort: a continuation token is
          // bound to the ordering it was issued for.
          Observer(
            builder: (_) => SegmentedButton<CommentSort>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12),
                ),
              ),
              segments: const [
                ButtonSegment(value: CommentSort.top, label: Text('Principais')),
                ButtonSegment(
                    value: CommentSort.newest, label: Text('Recentes')),
              ],
              selected: {_controller.commentSort},
              onSelectionChanged: (selection) =>
                  _controller.setCommentSort(selection.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentsSection() {
    return Observer(builder: (_) {
      if (_controller.isLoadingComments && _controller.comments.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (_controller.commentsError != null && _controller.comments.isEmpty) {
        return SliverToBoxAdapter(
          child: _sectionMessage(
            _controller.commentsError!,
            _controller.loadComments,
          ),
        );
      }
      if (_controller.comments.isEmpty) {
        return SliverToBoxAdapter(
          child: _sectionMessage('Nenhum comentário ainda', null),
        );
      }

      return SliverList.builder(
        itemCount: _controller.comments.length + 1,
        itemBuilder: (context, i) {
          if (i == _controller.comments.length) {
            return _buildCommentsFooter();
          }
          return CommentTile(comment: _controller.comments[i]);
        },
      );
    });
  }

  Widget _buildCommentsFooter() {
    if (_controller.isLoadingMoreComments) {
      final c = context.c;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_controller.hasMoreComments) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: TextButton(
            onPressed: _controller.loadMoreComments,
            child: const Text('Carregar mais comentários'),
          ),
        ),
      );
    }
    return const SizedBox(height: 12);
  }

  Widget _sectionMessage(String message, VoidCallback? retry) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 13.5),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

/// Landscape, immersive host. Reuses the same [VideoPlaybackController] so
/// entering and leaving fullscreen never re-buffers the stream.
class _FullscreenHost extends StatefulWidget {
  final VideoPlaybackController playback;
  final VoidCallback onClose;

  const _FullscreenHost({required this.playback, required this.onClose});

  @override
  State<_FullscreenHost> createState() => _FullscreenHostState();
}

class _FullscreenHostState extends State<_FullscreenHost> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.playback.aspectRatio,
          child: VideoPlayerSurface(
            controller: widget.playback,
            onToggleFullscreen: widget.onClose,
          ),
        ),
      ),
    );
  }
}
