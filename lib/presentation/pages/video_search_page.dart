import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';
import '../components/music_widgets.dart';
import '../controllers/video_search_controller.dart';
import '../controllers/player_controller.dart';
import '../widgets/video_widgets.dart';

/// Search in video mode, with YouTube's own refinement chips.
///
/// The chip bar is only meaningful for a concrete query, so it appears with the
/// results instead of sitting empty above them.
class VideoSearchPage extends StatefulWidget {
  final ContentSource source;
  final PlayerController playerController;
  final VoidCallback? onSettings;

  const VideoSearchPage({
    super.key,
    required this.source,
    required this.playerController,
    this.onSettings,
  });

  @override
  State<VideoSearchPage> createState() => _VideoSearchPageState();
}

class _VideoSearchPageState extends State<VideoSearchPage> {
  late final VideoSearchController _controller;
  final _fieldController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = VideoSearchController(widget.source);
  }

  @override
  void dispose() {
    _fieldController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _focusNode.unfocus();
    await _controller.search();
  }

  /// Results open the watch page rather than the audio player: tapping a video
  /// is a request to watch it, not to stream it as a track.
  void _openWatch(VideoModel video) {
    context.push('/watch', extra: video);
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      playerController: widget.playerController,
      child: Column(
        children: [
          _buildField(),
          // A Column hands non-flex children an unbounded height, and the
          // results are a ListView: without the Expanded the viewport has no
          // height to fill and the whole page fails to lay out, which is what
          // made a search that *returned* videos look like one that found none.
          Expanded(child: Observer(builder: (_) => _buildBody())),
        ],
      ),
    );
  }

  Widget _buildField() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _fieldController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              onChanged: _controller.setQuery,
              style: TextStyle(color: c.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Buscar vídeos',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 15),
                prefixIcon:
                    Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                suffixIcon: ListenableBuilder(
                  listenable: _fieldController,
                  builder: (context, _) => _fieldController.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: c.textMuted, size: 20),
                          onPressed: _clearField,
                        ),
                ),
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: c.textMuted, size: 22),
            onPressed: widget.onSettings,
          ),
        ],
      ),
    );
  }

  void _clearField() {
    _fieldController.clear();
    _controller.clear();
    _focusNode.requestFocus();
  }

  /// The chip bar stays up through loading and errors: it belongs to the query,
  /// not to one response, and removing a chip has to stay reachable when the
  /// refined search is the one that failed.
  Widget _buildBody() {
    if (_controller.submittedQuery.isEmpty) {
      return _buildHint('Busque um vídeo para começar');
    }

    final Widget content;
    if (_controller.errorMessage != null) {
      content = _buildHint(_controller.errorMessage!, retry: _submit);
    } else if (_controller.isLoading && !_controller.hasResults) {
      content = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_controller.isEmpty) {
      content = _buildHint(
          'Nenhum vídeo encontrado para "${_controller.submittedQuery}"');
    } else {
      content = const SizedBox.shrink();
    }

    final results = _controller.results;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: Observer(builder: (_) => _buildChips())),
        if (results.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: content)
        else
          // Built on demand: a results page is dozens of cards with
          // thumbnails, and building them all up front stalled the first frame.
          SliverList.builder(
            itemCount: results.length,
            itemBuilder: (context, i) => VideoCard(
              video: results[i],
              onTap: () => _openWatch(results[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildChips() {
    if (_controller.filters.isEmpty && !_controller.hasActiveFilters) {
      return const SizedBox.shrink();
    }
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Already-applied chips, removable. YouTube does not mark the active
        // chip itself, so the applied set is what the user sees.
        if (_controller.applied.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              itemCount: _controller.applied.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = _controller.applied[i];
                final isLast = i == _controller.applied.length - 1;
                return _Pill(
                  label: label,
                  filled: true,
                  color: c.primary,
                  foreground: c.onPrimary,
                  onTap: isLast ? _controller.removeLastFilter : null,
                  onRemove: isLast ? _controller.removeLastFilter : null,
                );
              },
            ),
          ),
        // Everything still on offer, fetched in the same context as the results.
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: _controller.filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final option = _controller.filters[i];
              return _Pill(
                label: option.label,
                color: c.surface,
                foreground: c.text,
                onTap: () => _controller.applyFilter(option),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHint(String message, {VoidCallback? retry}) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 14),
            ),
            if (retry != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;
  final bool filled;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _Pill({
    required this.label,
    required this.color,
    required this.foreground,
    this.filled = false,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 15, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
