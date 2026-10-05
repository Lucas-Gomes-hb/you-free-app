import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:mobx/mobx.dart';

import '../../app/theme.dart';
import '../controllers/home_controller.dart';
import '../controllers/player_controller.dart';
import '../components/video_card.dart';
import '../components/channel_card.dart';
import '../components/music_widgets.dart';

/// Standalone search tab, split out of the home page: search field, type
/// chips, suggestion dropdown and results.
class SearchPage extends StatefulWidget {
  final HomeController controller;
  final PlayerController playerController;

  const SearchPage({
    Key? key,
    required this.controller,
    required this.playerController,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _searchScrollController = ScrollController();

  String? _loadingChannelId;
  String? _loadingPlaylistId;

  List<String> _ytSuggestions = [];
  List<String> _historyMatches = [];
  bool _showSuggestions = false;
  Timer? _suggestDebounce;
  ReactionDisposer? _searchQueryReaction;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        setState(() => _showSuggestions = false);
      }
    });
    _searchScrollController.addListener(_onSearchScroll);

    // Keep the field in sync when the query changes elsewhere (e.g. clearing
    // from the bottom nav).
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

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchQueryReaction?.call();
    _searchScrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Suggestions ──────────────────────────────────────────────────────────

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

    if (query.trim().isNotEmpty) {
      _loadHistoryMatches(query.trim());
    } else {
      if (mounted) setState(() { _historyMatches = []; _showSuggestions = false; });
      return;
    }

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

  List<SuggestionItem> get _combinedSuggestions {
    final historySet = _historyMatches.toSet();
    final ytOnly = _ytSuggestions.where((s) => !historySet.contains(s)).toList();
    return [
      ..._historyMatches.map((s) => SuggestionItem(s, true)),
      ...ytOnly.map((s) => SuggestionItem(s, false)),
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

  void _clearSearch() {
    _searchController.clear();
    widget.controller.clearSearch();
    _focusNode.unfocus();
    setState(() {
      _ytSuggestions = [];
      _historyMatches = [];
      _showSuggestions = false;
    });
  }

  // ── Collections ──────────────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      playerController: widget.playerController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          _buildTypeChips(),
          Expanded(
            child: Stack(
              children: [
                _buildBody(),
                if (_showSuggestions) _buildSuggestionsOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
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
                    onPressed: _clearSearch,
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
            MusicFilterChip(
              label: 'Músicas',
              selected: widget.controller.searchType == SearchType.videos,
              onTap: () => widget.controller.setSearchType(SearchType.videos),
            ),
            const SizedBox(width: 8),
            MusicFilterChip(
              label: 'Artistas',
              selected: widget.controller.searchType == SearchType.artists,
              onTap: () => widget.controller.setSearchType(SearchType.artists),
            ),
            const SizedBox(width: 8),
            MusicFilterChip(
              label: 'Álbuns',
              selected: widget.controller.searchType == SearchType.albums,
              onTap: () => widget.controller.setSearchType(SearchType.albums),
            ),
          ],
        ),
      ),
    );
  }

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
        return widget.controller.searchQuery.isNotEmpty ? _buildEmpty() : _buildIdle();
      }
      return _buildResults();
    });
  }

  Widget _buildIdle() {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: c.textMuted),
          const SizedBox(height: 14),
          Text(
            'Busque suas músicas favoritas',
            style: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite um nome, artista ou cole uma URL',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

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
              return MusicPlaylistTile(
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

  Widget _buildEmpty() {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: c.textMuted),
          const SizedBox(height: 14),
          Text(
            'Nenhum resultado encontrado',
            style: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
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

  // ── Suggestions overlay ──────────────────────────────────────────────────

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
}
