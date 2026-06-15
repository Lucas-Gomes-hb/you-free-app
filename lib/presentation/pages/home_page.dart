import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../controllers/home_controller.dart';
import '../controllers/player_controller.dart';
import '../components/video_card.dart';
import '../components/channel_card.dart';
import '../../data/models/video_model.dart';
import '../../data/models/collection_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Small helper to distinguish local-history items from remote suggestions
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionItem {
  final String text;
  final bool isHistory;
  const _SuggestionItem(this.text, this.isHistory);
}

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
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  String? _loadingChannelId;
  String? _loadingPlaylistId;

  List<VideoModel> _homeFeed = [];
  bool _homeFeedLoading = false;
  bool _loadingMore = false;
  final Set<String> _seenFeedIds = {};
  int _feedSeedIndex = 0;
  final _feedScrollController = ScrollController();

  // ── Suggestions ──────────────────────────────────────────────────────────
  List<String> _ytSuggestions = [];   // remote YouTube suggestions
  List<String> _historyMatches = [];  // local search history
  bool _showSuggestions = false;
  Timer? _suggestDebounce;
  ReactionDisposer? _searchQueryReaction;
  // ─────────────────────────────────────────────────────────────────────────

  final _searchScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        setState(() => _showSuggestions = false);
      }
    });
    _feedScrollController.addListener(_onFeedScroll);
    _searchScrollController.addListener(_onSearchScroll);
    _loadHomeFeed();

    // Sync the text field when the controller's query is cleared externally
    // (e.g. by tapping the Home tab in the bottom nav).
    _searchQueryReaction = reaction(
      (_) => widget.controller.searchQuery,
      (String q) {
        if (q.isEmpty && _searchController.text.isNotEmpty && mounted) {
          _searchController.clear();
          setState(() {
            _ytSuggestions = [];
            _historyMatches = [];
            _showSuggestions = false;
          });
        }
      },
    );
  }

  void _onSearchScroll() {
    final pos = _searchScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      widget.controller.loadMoreSearch();
    }
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
    _suggestDebounce?.cancel();
    _searchQueryReaction?.call();
    _feedScrollController.dispose();
    _searchScrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Suggestions logic ───────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    widget.controller.setSearchQuery(query);
    _suggestDebounce?.cancel();

    if (_isUrlOrHandle(query)) {
      if (mounted) {
        setState(() {
          _ytSuggestions = [];
          _historyMatches = [];
          _showSuggestions = false;
        });
      }
      return;
    }

    // Load local history immediately for any non-empty query
    if (query.trim().isNotEmpty) {
      _loadHistoryMatches(query.trim());
    } else {
      if (mounted) setState(() { _historyMatches = []; _showSuggestions = false; });
      return;
    }

    // Fetch remote YouTube suggestions for queries ≥ 2 chars
    if (query.trim().length < 2) return;

    _suggestDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.controller.getSearchSuggestions(query.trim());
      if (mounted && _focusNode.hasFocus) {
        setState(() {
          _ytSuggestions = results;
          _showSuggestions = _historyMatches.isNotEmpty || results.isNotEmpty;
        });
      }
    });
  }

  Future<void> _loadHistoryMatches(String prefix) async {
    final history = await widget.controller.getSearchHistory(prefix);
    if (mounted && _focusNode.hasFocus) {
      setState(() {
        _historyMatches = history;
        _showSuggestions = history.isNotEmpty || _ytSuggestions.isNotEmpty;
      });
    }
  }

  List<_SuggestionItem> get _combinedSuggestions {
    final historySet = _historyMatches.toSet();
    final ytOnly = _ytSuggestions.where((s) => !historySet.contains(s)).toList();
    return [
      ..._historyMatches.map((s) => _SuggestionItem(s, true)),
      ...ytOnly.map((s) => _SuggestionItem(s, false)),
    ];
  }

  void _applySuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.collapsed(offset: suggestion.length);
    widget.controller.setSearchQuery(suggestion);
    setState(() {
      _ytSuggestions = [];
      _historyMatches = [];
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    _handleSearch();
  }

  bool _isUrlOrHandle(String q) =>
      q.startsWith('@') ||
      q.contains('youtube.com') ||
      q.contains('youtu.be') ||
      q.startsWith('http');

  void _handleSearch() {
    final query = widget.controller.searchQuery.trim();
    if (query.isEmpty) return;
    if (_isUrlOrHandle(query)) {
      _loadCollection(query);
    } else if (widget.controller.searchType == SearchType.artists) {
      widget.controller.searchChannels();
    } else if (widget.controller.searchType == SearchType.albums) {
      widget.controller.searchPlaylists();
    } else {
      widget.controller.search();
    }
    _focusNode.unfocus();
  }

  Future<void> _loadCollection(String url) async {
    final col = await widget.controller.fetchCollection(url);
    if (col != null && mounted) {
      context.push('/collection', extra: {'collection': col, 'playerController': widget.playerController});
    }
  }

  Future<void> _openPlaylist(String id, String url) async {
    setState(() => _loadingPlaylistId = id);
    try {
      final col = await widget.controller.fetchCollection(url);
      if (col != null && mounted) {
        context.push('/collection', extra: {'collection': col, 'playerController': widget.playerController});
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylistId = null);
    }
  }

  Future<void> _openChannel(String id, String? url) async {
    if (url == null) return;
    setState(() => _loadingChannelId = id);
    try {
      final col = await widget.controller.fetchCollection(url);
      if (col != null && mounted) {
        context.push('/collection', extra: {'collection': col, 'playerController': widget.playerController});
      }
    } finally {
      if (mounted) setState(() => _loadingChannelId = null);
    }
  }

  // ── Suggestions overlay ────────────────────────────────────────────────

  Widget _buildSuggestionsOverlay() {
    final c = context.c;
    final items = _combinedSuggestions;
    if (items.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: c.border, indent: 48),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => _applySuggestion(item.text),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      item.isHistory ? Icons.history_rounded : Icons.search_rounded,
                      size: 16,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (item.isHistory)
                      GestureDetector(
                        onTap: () {
                          widget.controller.deleteSearchHistoryEntry(item.text);
                          setState(() => _historyMatches.remove(item.text));
                        },
                        child: Icon(Icons.close_rounded, size: 15, color: c.textMuted),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          _searchController.text = item.text;
                          _searchController.selection =
                              TextSelection.collapsed(offset: item.text.length);
                          widget.controller.setSearchQuery(item.text);
                          setState(() {
                            _ytSuggestions = [];
                            _historyMatches = [];
                            _showSuggestions = false;
                          });
                        },
                        child: Icon(Icons.north_west_rounded, size: 15, color: c.textMuted),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Observer(builder: (_) {
        final thumb = widget.playerController.currentVideo?.thumbnail;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Ambient blurred background from currently playing song
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
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  _buildTypeChips(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildBody(),
                        if (_showSuggestions)
                          _buildSuggestionsOverlay(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHeader() {
    final c = context.c;
    return Observer(builder: (_) {
      final hasSearch = widget.controller.searchQuery.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: hasSearch
                  ? () {
                      _searchController.clear();
                      widget.controller.clearSearch();
                      _focusNode.unfocus();
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
            ),
            const Spacer(),
            if (hasSearch)
              IconButton(
                icon: Icon(Icons.close_rounded, color: c.textMuted, size: 22),
                onPressed: () {
                  _searchController.clear();
                  widget.controller.clearSearch();
                  _focusNode.unfocus();
                },
                tooltip: 'Limpar pesquisa',
              )
            else
              IconButton(
                icon: Icon(Icons.settings_rounded, color: c.textMuted, size: 22),
                onPressed: widget.onSettings,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Observer(
        builder: (_) => TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(color: c.text, fontSize: 15),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar músicas, artistas, URL...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.textMuted),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: widget.controller.searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      widget.controller.clearSearch();
                      _focusNode.unfocus();
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            setState(() {
              _ytSuggestions = [];
              _historyMatches = [];
              _showSuggestions = false;
            });
            _handleSearch();
          },
        ),
      ),
    );
  }

  Widget _buildTypeChips() {
    return Observer(
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            _Chip(
              label: 'Músicas',
              selected: widget.controller.searchType == SearchType.videos,
              onTap: () => widget.controller.setSearchType(SearchType.videos),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Artistas',
              selected: widget.controller.searchType == SearchType.artists,
              onTap: () => widget.controller.setSearchType(SearchType.artists),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Álbuns',
              selected: widget.controller.searchType == SearchType.albums,
              onTap: () => widget.controller.setSearchType(SearchType.albums),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final c = context.c;
    return Observer(builder: (_) {
      if (widget.controller.isLoading) {
        return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2));
      }
      if (widget.controller.errorMessage != null) return _buildError();

      final hasResults = widget.controller.videos.isNotEmpty ||
          widget.controller.channels.isNotEmpty ||
          widget.controller.playlists.isNotEmpty;

      if (!hasResults) {
        return widget.controller.searchQuery.isNotEmpty ? _buildEmpty() : _buildHomeScreen();
      }
      return _buildResults();
    });
  }

  // ── Home screen ──────────────────────────────────────────────────────────

  Widget _buildHomeScreen() {
    final c = context.c;
    return Observer(builder: (_) {
      final history = widget.controller.recentlyPlayed;
      final feedEmpty = _homeFeed.isEmpty && !_homeFeedLoading;

      if (history.isEmpty && feedEmpty) return _buildEmpty();

      return CustomScrollView(
        controller: _feedScrollController,
        slivers: [
          if (history.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHeader('Recentemente ouvidas')),
            SliverPadding(
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
                    final v = history[i];
                    return Observer(
                      builder: (_) => _QuickPlayTile(
                        video: v,
                        isPlaying: widget.playerController.isCurrentVideo(v.id) &&
                            widget.playerController.isPlaying,
                        onTap: () => widget.playerController.loadVideo(v),
                      ),
                    );
                  },
                  childCount: history.length,
                ),
              ),
            ),
          ],

          if (_homeFeedLoading || _homeFeed.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHeader('Para você')),
            if (_homeFeedLoading && _homeFeed.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LinearProgressIndicator(
                    color: c.primary,
                    backgroundColor: c.surfaceHigh,
                    minHeight: 2,
                  ),
                ),
              )
            else
              SliverPadding(
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
                      final v = _homeFeed[i];
                      return Observer(
                        builder: (_) => _QuickPlayTile(
                          video: v,
                          isPlaying: widget.playerController.isCurrentVideo(v.id) &&
                              widget.playerController.isPlaying,
                          onTap: () => widget.playerController.loadVideo(v),
                        ),
                      );
                    },
                    childCount: _homeFeed.length,
                  ),
                ),
              ),
          ],

          SliverToBoxAdapter(
            child: _loadingMore
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                          color: c.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(height: 20),
          ),
        ],
      );
    });
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

  // ── Search results ───────────────────────────────────────────────────────

  Widget _buildResults() {
    return Observer(builder: (_) {
      if (widget.controller.channels.isNotEmpty) return _buildChannelResults();
      if (widget.controller.playlists.isNotEmpty) return _buildPlaylistResults();
      return _buildVideoResults();
    });
  }

  Widget _buildSearchHeader(String label) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: c.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
          child: Text(
            'Resultados para',
            style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '"${widget.controller.searchQuery}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildVideoResults() {
    final c = context.c;
    return Observer(builder: (_) {
      final videos = widget.controller.videos;
      final loadingMore = widget.controller.isLoadingMoreSearch;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchHeader('${videos.length} músicas encontradas'),
          Expanded(
            child: ListView.builder(
              controller: _searchScrollController,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: videos.length + 1,
              itemBuilder: (ctx, i) {
                if (i == videos.length) {
                  return loadingMore
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: c.primary, strokeWidth: 2),
                            ),
                          ),
                        )
                      : const SizedBox(height: 8);
                }
                return Observer(
                  builder: (_) => VideoCard(
                    video: videos[i],
                    isCurrentlyPlaying: widget.playerController.isCurrentVideo(videos[i].id),
                    onTap: () => widget.playerController.loadVideo(videos[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildChannelResults() {
    final c = context.c;
    final channels = widget.controller.channels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchHeader('${channels.length} artistas encontrados'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: channels.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 86, color: c.border),
            itemBuilder: (ctx, i) {
              final ch = channels[i];
              return ChannelCard(
                channel: ch,
                isLoading: _loadingChannelId == ch.id,
                onTap: () => _openChannel(ch.id, ch.url),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistResults() {
    final c = context.c;
    final playlists = widget.controller.playlists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchHeader('${playlists.length} álbuns/playlists encontrados'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 86, color: c.border),
            itemBuilder: (ctx, i) {
              final pl = playlists[i];
              return _PlaylistTile(
                playlist: pl,
                isLoading: _loadingPlaylistId == pl.id,
                onTap: () => _openPlaylist(pl.id, pl.url),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Empty / error ────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final c = context.c;
    final hasQuery = widget.controller.searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.music_note_rounded,
            size: 64,
            color: c.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            hasQuery ? 'Nenhum resultado encontrado' : 'Busque suas músicas favoritas',
            style: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 8),
            Text('Digite um nome, artista ou cole uma URL',
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
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
              onPressed: _handleSearch,
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

// =============================================================================
// Filter chip
// =============================================================================

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

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

// =============================================================================
// Quick-play tile
// =============================================================================

class _QuickPlayTile extends StatelessWidget {
  final VideoModel video;
  final bool isPlaying;
  final VoidCallback onTap;

  const _QuickPlayTile({required this.video, required this.isPlaying, required this.onTap});

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

// =============================================================================
// Playlist tile (for search results)
// =============================================================================

class _PlaylistTile extends StatelessWidget {
  final PlaylistPreview playlist;
  final VoidCallback onTap;
  final bool isLoading;

  const _PlaylistTile({required this.playlist, required this.onTap, this.isLoading = false});

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
