import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../controllers/home_controller.dart';
import '../controllers/player_controller.dart';
import '../components/music_widgets.dart';
import '../../data/models/video_model.dart';

/// Music home: just the feed. Searching lives in its own tab now, so there is
/// no search field or result list here anymore.
class HomePage extends StatefulWidget {
  final HomeController controller;
  final PlayerController playerController;
  final VoidCallback? onSettings;

  const HomePage({
    Key? key,
    required this.controller,
    required this.playerController,
    this.onSettings,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<VideoModel> _homeFeed = [];
  bool _homeFeedLoading = false;
  bool _loadingMore = false;
  final Set<String> _seenFeedIds = {};
  int _feedSeedIndex = 0;
  final _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_onFeedScroll);
    _loadHomeFeed();
  }

  void _onFeedScroll() {
    final pos = _feedScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 && !_loadingMore) {
      _loadMoreFeed();
    }
  }

  Future<void> _loadMoreFeed() async {
    final history = widget.controller.recentlyPlayed;
    final seeds = history.isNotEmpty ? history : _homeFeed.take(5).toList();
    if (seeds.isEmpty || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final seed = seeds[_feedSeedIndex % seeds.length];
      _feedSeedIndex++;
      final more = await widget.controller.loadMoreFeed(seed);
      if (!mounted) return;
      final fresh = more.where((v) => !_seenFeedIds.contains(v.id)).toList();
      if (fresh.isNotEmpty) {
        setState(() {
          for (final v in fresh) _seenFeedIds.add(v.id);
          _homeFeed.addAll(fresh);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadHomeFeed() async {
    if (!mounted) return;
    setState(() => _homeFeedLoading = true);
    try {
      final feed = await widget.controller.loadHomeFeed();
      if (mounted) {
        setState(() {
          _homeFeed = feed;
          _seenFeedIds.addAll(feed.map((v) => v.id));
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _homeFeedLoading = false);
    }
  }

  @override
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
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
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
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
      if (widget.controller.errorMessage != null) return _buildError();
      final history = widget.controller.recentlyPlayed;
      final feedEmpty = _homeFeed.isEmpty && !_homeFeedLoading;
      if (history.isEmpty && feedEmpty) return _buildEmpty();

      return CustomScrollView(
        controller: _feedScrollController,
        slivers: [
if (history.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHeader('Recentemente ouvidas')),
            _tileGrid(history, asHistory: true),
          ],
          if (_homeFeedLoading || _homeFeed.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHeader('Para você')),
            if (_homeFeedLoading && _homeFeed.isEmpty)
              SliverToBoxAdapter(child: _feedProgress())
            else
              _tileGrid(_homeFeed),
          ],
          SliverToBoxAdapter(child: _loadMoreIndicator()),
        ],
      );
    });
  }

  Widget _tileGrid(List<VideoModel> items, {bool asHistory = false}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 3.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final v = items[i];
            return Observer(
              builder: (_) => QuickPlayTile(
                video: v,
                isPlaying: widget.playerController.isCurrentVideo(v.id) &&
                    widget.playerController.isPlaying,
                // History is shared with the video experience, so an entry
                // that was watched with picture goes back to the Watch page
                // instead of playing as an audio-only track.
                onTap: () => asHistory && v.playedAsVideo
                    ? context.push('/watch', extra: v)
                    : widget.playerController.loadVideo(v),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _feedProgress() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LinearProgressIndicator(
        color: c.primary,
        backgroundColor: c.surfaceHigh,
        minHeight: 2,
      ),
    );
  }

  Widget _loadMoreIndicator() {
    final c = context.c;
    if (!_loadingMore) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: 64, color: c.textMuted),
          const SizedBox(height: 14),
          Text(
            'Nada para tocar ainda',
            style: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Use a aba Busca para achar músicas',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(50)),
              child: Icon(Icons.wifi_off_rounded, size: 40, color: c.secondary),
            ),
            const SizedBox(height: 20),
            Text('Algo deu errado',
                style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              widget.controller.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHomeFeed,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
