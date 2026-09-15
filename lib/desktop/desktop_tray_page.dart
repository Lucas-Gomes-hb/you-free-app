import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/theme.dart';
import '../data/models/video_model.dart';
import 'desktop_controller.dart';

class DesktopTrayPage extends StatefulWidget {
  final DesktopController controller;

  const DesktopTrayPage({super.key, required this.controller});

  @override
  State<DesktopTrayPage> createState() => _DesktopTrayPageState();
}

class _DesktopTrayPageState extends State<DesktopTrayPage> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _suggestDebounce;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _suggestDebounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _suggestions = [];
        widget.controller.setSearchQuery('');
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String query) {
    widget.controller.setSearchQuery(query);
    _suggestDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.controller.getSearchSuggestions(query.trim());
      if (mounted) {
        setState(() => _suggestions = results);
      }
    });
  }

  void _applySearch(String query) {
    _searchController.text = query;
    widget.controller.setSearchQuery(query);
    _suggestions = [];
    _focusNode.unfocus();
    widget.controller.search();
  }

  void _handleSearchSubmit() {
    _suggestions = [];
    _focusNode.unfocus();
    widget.controller.search();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final video = widget.controller.currentVideo;

    return Container(
      color: c.background,
      child: Column(
        children: [
          _buildHeader(c),
          if (_showSearch)
            Expanded(child: _buildSearchBar(c))
          else ...[
            Expanded(child: _buildPlayerContent(c, video)),
            if (video != null) _buildControls(c),
            if (video != null) _buildProgressBar(c),
            if (video != null && widget.controller.suggestions.isNotEmpty)
              _buildSuggestions(c),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(AppPalette c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/youfree.png', width: 28, height: 28),
          ),
          const SizedBox(width: 8),
          Text(
            'YouFree',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.text,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          _IconBtn(
            icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
            color: c.textMuted,
            onTap: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: TextStyle(color: c.text, fontSize: 14),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar músicas...',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _handleSearchSubmit(),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: c.border.withValues(alpha: 0.3)),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => _applySearch(_suggestions[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 15, color: c.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _suggestions[i],
                            style: TextStyle(color: c.text, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.controller.isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                color: c.primary,
                backgroundColor: c.surfaceHigh,
                minHeight: 1.5,
              ),
            ),
          if (widget.controller.searchResults.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 6),
                itemCount: widget.controller.searchResults.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 60, color: c.border.withValues(alpha: 0.3)),
                itemBuilder: (_, i) {
                  final v = widget.controller.searchResults[i];
                  return _SearchResultTile(
                    video: v,
                    onTap: () {
                      _showSearch = false;
                      _searchController.clear();
                      widget.controller.loadVideo(v);
                    },
                  );
                },
              ),
            ),
          if (!widget.controller.isSearching &&
              widget.controller.searchResults.isEmpty &&
              widget.controller.searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Nenhum resultado',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent(AppPalette c, VideoModel? video) {
    if (video == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.music_note_rounded, size: 48, color: c.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Nada tocando',
              style: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Busque uma música para começar',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (widget.controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: video.thumbnail != null
                ? CachedNetworkImage(
                    imageUrl: video.thumbnail!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _artPlaceholder(c),
                    errorWidget: (_, __, ___) => _artPlaceholder(c),
                  )
                : _artPlaceholder(c),
          ),
          const SizedBox(height: 14),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.text,
              height: 1.2,
            ),
          ),
          if (video.uploader != null) ...[
            const SizedBox(height: 4),
            Text(
              video.uploader!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildControls(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: Icons.skip_previous_rounded,
            size: 28,
            color: c.text,
            onTap: widget.controller.skipToPrevious,
          ),
          GestureDetector(
            onTap: widget.controller.togglePlayPause,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 30,
                color: c.onPrimary,
              ),
            ),
          ),
          _ControlBtn(
            icon: Icons.skip_next_rounded,
            size: 28,
            color: c.text,
            onTap: widget.controller.skipToNext,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: c.primary,
              inactiveTrackColor: c.surfaceHigh,
              thumbColor: c.primary,
              overlayColor: c.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: widget.controller.progress.clamp(0.0, 1.0),
              onChanged: (v) {
                widget.controller.seek(Duration(
                  milliseconds: (v * widget.controller.duration.inMilliseconds).toInt(),
                ));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(widget.controller.position),
                    style: TextStyle(fontSize: 11, color: c.textMuted)),
                Text(_fmt(widget.controller.duration),
                    style: TextStyle(fontSize: 11, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(AppPalette c) {
    final s = widget.controller.suggestions;
    final loading = widget.controller.isSuggestionsLoading;

    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Text(
                  'A seguir',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: s.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 54,
                color: c.border.withValues(alpha: 0.3),
              ),
              itemBuilder: (_, i) {
                final v = s[i];
                return InkWell(
                  onTap: () => widget.controller.advanceInQueue(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: v.thumbnail != null
                              ? CachedNetworkImage(
                                  imageUrl: v.thumbnail!,
                                  width: 36, height: 36, fit: BoxFit.cover,
                                  placeholder: (_, __) => _tinyPlaceholder(c),
                                  errorWidget: (_, __, ___) => _tinyPlaceholder(c),
                                )
                              : _tinyPlaceholder(c),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (v.uploader != null)
                                Text(
                                  v.uploader!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.textMuted, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _artPlaceholder(AppPalette c) {
    return Container(
      width: double.infinity,
      height: 200,
      color: c.surface,
      child: Icon(Icons.music_note_rounded, size: 64, color: c.textMuted),
    );
  }

  Widget _tinyPlaceholder(AppPalette c) {
    return Container(
      width: 36, height: 36,
      color: c.surfaceHigh,
      child: Icon(Icons.music_note_rounded, size: 16, color: c.textMuted),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.size, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: color,
      onPressed: onTap,
      splashRadius: 22,
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const _SearchResultTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: video.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnail!,
                      width: 48, height: 48, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 48, height: 48, color: c.surfaceHigh),
                      errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: c.surfaceHigh),
                    )
                  : Container(width: 48, height: 48, color: c.surfaceHigh),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (video.uploader != null)
                    Text(
                      video.uploader!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              video.durationFormatted,
              style: TextStyle(color: c.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
