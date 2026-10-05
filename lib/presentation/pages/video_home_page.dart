import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/services/content_source.dart';
import '../components/music_widgets.dart';
import '../controllers/player_controller.dart';
import '../controllers/video_home_controller.dart';
import '../widgets/video_widgets.dart';

/// Video home: a single endless feed, the shape a phone screen wants.
class VideoHomePage extends StatefulWidget {
  final ContentSource source;
  final PlayerController playerController;
  final VoidCallback? onSettings;

  const VideoHomePage({
    super.key,
    required this.source,
    required this.playerController,
    this.onSettings,
  });

  @override
  State<VideoHomePage> createState() => _VideoHomePageState();
}

class _VideoHomePageState extends State<VideoHomePage> {
  late final VideoHomeController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = VideoHomeController(widget.source);
    _scrollController.addListener(_onScroll);
    _controller.load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      playerController: widget.playerController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/youfree.png', width: 34, height: 34),
          ),
          const SizedBox(width: 10),
          Text(
            'YouFree',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.text,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: c.textMuted, size: 22),
            onPressed: widget.onSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Observer(builder: (_) {
      if (_controller.errorMessage != null &&
          _controller.feed.isEmpty) {
        return _buildMessage(
          icon: Icons.wifi_off_rounded,
          message: _controller.errorMessage!,
          action: TextButton.icon(
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tentar novamente'),
          ),
        );
      }
      if (_controller.isLoading && _controller.feed.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_controller.isEmpty) {
        return _buildMessage(
          icon: Icons.video_library_rounded,
          message: 'Nada para assistir ainda',
          action: TextButton.icon(
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Recarregar'),
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _controller.feed.length + 1,
        itemBuilder: (context, i) {
          if (i == _controller.feed.length) {
            return _buildFooter();
          }
          final video = _controller.feed[i];
          return VideoCard(
            video: video,
            onTap: () => context.push('/watch', extra: video),
          );
        },
      );
    });
  }

  Widget _buildFooter() {
    if (!_controller.isLoadingMore) {
      return Observer(builder: (_) {
        if (_controller.errorMessage == null) {
          return const SizedBox(height: 24);
        }
        return _inlineError();
      });
    }
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _inlineError() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Não foi possível carregar mais',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _controller.loadMore,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: c.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
