import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../controllers/player_controller.dart';
import '../components/video_card.dart';
import '../../data/models/video_model.dart';
import '../../data/services/download_manager.dart';

class PlayerPage extends StatefulWidget {
  final PlayerController controller;
  final DownloadManager downloadManager;
  final VideoModel video;
  final ValueNotifier<bool> pipModeNotifier;

  const PlayerPage({
    Key? key,
    required this.controller,
    required this.downloadManager,
    required this.video,
    required this.pipModeNotifier,
  }) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static const _pipChannel = MethodChannel('com.example.youfree/pip');
  final GlobalKey _videoContainerKey = GlobalKey();

  bool _showLyrics = false;
  ReactionDisposer? _videoReaction;

  bool get _isPipMode => widget.pipModeNotifier.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.pipModeNotifier.addListener(_onPipModeChanged);
    widget.controller.loadVideo(widget.video);

    _videoReaction = reaction(
      (_) => widget.controller.currentVideo?.id,
      (id) {
        if (_showLyrics && id != null) {
          final v = widget.controller.currentVideo!;
          widget.controller.loadLyrics(v.title ?? '', v.uploader ?? '');
        }
      },
    );
  }

  void _onPipModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        widget.controller.isVideoMode &&
        !_isPipMode) {
      widget.controller.switchToAudioMode();
    }
  }

  @override
  void dispose() {
    _videoReaction?.call();
    WidgetsBinding.instance.removeObserver(this);
    widget.pipModeNotifier.removeListener(_onPipModeChanged);
    super.dispose();
  }

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod('updatePipState', widget.controller.isPlaying);
      Map<String, int>? bounds;
      final box = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        final ratio = MediaQuery.of(context).devicePixelRatio;
        bounds = {
          'left': (offset.dx * ratio).round(),
          'top': (offset.dy * ratio).round(),
          'right': ((offset.dx + box.size.width) * ratio).round(),
          'bottom': ((offset.dy + box.size.height) * ratio).round(),
        };
      }
      await _pipChannel.invokeMethod('enterPip', bounds);
    } catch (_) {}
  }

  void _toggleLyrics() {
    final v = widget.controller.currentVideo;
    setState(() { _showLyrics = !_showLyrics; });
    if (_showLyrics && v != null && !widget.controller.lyricsLoaded && !widget.controller.lyricsLoading) {
      widget.controller.loadLyrics(v.title ?? '', v.uploader ?? '');
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isPipMode) {
      return PopScope(
        canPop: false,
        child: Observer(builder: (_) {
          final vc = widget.controller.videoController;
          return Container(
            color: Colors.black,
            child: vc != null && vc.value.isInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: vc.value.aspectRatio,
                      child: VideoPlayer(vc),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Observer(builder: (_) {
          if (widget.controller.isLoading && widget.controller.currentVideo == null) {
            return const SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFE8432A), strokeWidth: 2),
              ),
            );
          }
          if (widget.controller.errorMessage != null) return _buildError();
          return _buildPlayer();
        }),
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFF5C030)),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => widget.controller.loadVideo(widget.video),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8432A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return Observer(builder: (_) {
      final video = widget.controller.currentVideo ?? widget.video;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (video.thumbnail != null) ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: _thumbImage(video.thumbnail!, fit: BoxFit.cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.72)),
          ],
          SafeArea(
            child: _showLyrics
                ? _buildLyricsLayout(video)
                : _buildNormalLayout(video),
          ),
        ],
      );
    });
  }

  Widget _buildNormalLayout(VideoModel video) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildArtwork(video.thumbnail),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildTitleSection(video.title, video.uploader ?? ''),
                      const SizedBox(height: 20),
                      _buildProgressBar(),
                      const SizedBox(height: 12),
                      _buildControls(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _buildSuggestions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsLayout(VideoModel video) {
    return Column(
      children: [
        _buildTopBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      video.uploader ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildLyricsPanel()),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: [
              _buildProgressBar(),
              const SizedBox(height: 12),
              _buildControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsPanel() {
    return Observer(builder: (_) {
      final ctrl = widget.controller;
      if (ctrl.lyricsLoading) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8432A), strokeWidth: 2),
        );
      }
      if (ctrl.lyricsLoaded && ctrl.plainLyrics == null && ctrl.syncedLyrics == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_rounded, size: 48, color: Colors.white12),
              const SizedBox(height: 12),
              const Text(
                'Letra não disponível',
                style: TextStyle(color: Color(0xFF666666), fontSize: 15),
              ),
            ],
          ),
        );
      }
      if (ctrl.syncedLyrics != null) {
        final lines = _parseLrc(ctrl.syncedLyrics!);
        if (lines.isNotEmpty) {
          return Observer(builder: (_) {
            return _SyncedLyricsView(
              key: ValueKey(ctrl.currentVideo?.id),
              lines: lines,
              position: ctrl.position,
            );
          });
        }
      }
      if (ctrl.plainLyrics != null) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            ctrl.plainLyrics!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.7,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildTopBar() {
    final isVideoMode = widget.controller.isVideoMode;
    final isLoading = widget.controller.isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Reproduzindo agora',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.lyrics_rounded,
                  size: 22,
                  color: _showLyrics ? const Color(0xFF00897B) : Colors.white70,
                ),
                tooltip: 'Letra',
                onPressed: _toggleLyrics,
              ),
              if (isVideoMode)
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 22),
                  color: Colors.white70,
                  tooltip: 'Picture in picture',
                  onPressed: _enterPip,
                ),
              IconButton(
                icon: Icon(
                  isVideoMode ? Icons.headphones_rounded : Icons.videocam_rounded,
                  size: 22,
                ),
                color: Colors.white70,
                tooltip: isVideoMode ? 'Modo áudio' : 'Modo vídeo',
                onPressed: isLoading
                    ? null
                    : (isVideoMode
                        ? widget.controller.switchToAudioMode
                        : widget.controller.switchToVideoMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(String? thumb) {
    if (widget.controller.isVideoMode && widget.controller.videoController != null) {
      return KeyedSubtree(
        key: _videoContainerKey,
        child: _buildVideoPlayer(widget.controller.videoController!),
      );
    }
    return _buildThumbnail(thumb);
  }

  Widget _buildVideoPlayer(VideoPlayerController vc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          final height = vc.value.isInitialized
              ? width / vc.value.aspectRatio
              : width * 9 / 16;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: vc.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: vc.value.aspectRatio,
                      child: VideoPlayer(vc),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8432A),
                        strokeWidth: 2,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _thumbImage(String url, {BoxFit fit = BoxFit.cover}) {
    final hiRes = url.replaceAllMapped(
      RegExp(r'(sq|mq|sd|hq)?default\.jpg'),
      (_) => 'maxresdefault.jpg',
    );
    if (hiRes == url) {
      return CachedNetworkImage(
        imageUrl: url, fit: fit,
        placeholder: (_, __) => _artworkPlaceholder(),
        errorWidget: (_, __, ___) => _artworkPlaceholder(),
      );
    }
    return CachedNetworkImage(
      imageUrl: hiRes, fit: fit,
      placeholder: (_, __) => _artworkPlaceholder(),
      errorWidget: (_, __, ___) => CachedNetworkImage(
        imageUrl: url, fit: fit,
        placeholder: (_, __) => _artworkPlaceholder(),
        errorWidget: (_, __, ___) => _artworkPlaceholder(),
      ),
    );
  }

  Widget _buildThumbnail(String? thumb) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final size = constraints.maxWidth;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumb != null
                  ? _thumbImage(thumb, fit: BoxFit.cover)
                  : _artworkPlaceholder(),
            ),
          );
        },
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Icon(Icons.music_note_rounded, size: 80, color: Colors.grey[800]),
    );
  }

  Widget _buildTitleSection(String title, String uploader) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                uploader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildDownloadButton(),
      ],
    );
  }

  Widget _buildDownloadButton() {
    // Observer reacts to currentVideo changes; ListenableBuilder reacts to download progress
    return Observer(builder: (_) {
      final video = widget.controller.currentVideo;
      if (video == null) return const SizedBox(width: 48);
      return ListenableBuilder(
        listenable: widget.downloadManager,
        builder: (context, _) {
          final info = widget.downloadManager.infoFor(video.id);
          switch (info.status) {
            case DownloadStatus.none:
              return IconButton(
                icon: const Icon(Icons.download_rounded, color: Color(0xFFAAAAAA)),
                tooltip: 'Baixar',
                onPressed: () => widget.downloadManager.download(video),
              );
            case DownloadStatus.downloading:
              return SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                          value: info.progress > 0 ? info.progress : null,
                          strokeWidth: 2.5,
                          color: const Color(0xFFE8432A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.downloadManager.cancel(video.id),
                        child: const Icon(Icons.close_rounded, size: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            case DownloadStatus.done:
              return IconButton(
                icon: const Icon(Icons.download_done_rounded, color: Color(0xFFE8432A)),
                onPressed: null,
              );
            case DownloadStatus.error:
              return IconButton(
                icon: const Icon(Icons.error_outline_rounded, color: Colors.orange),
                onPressed: () => widget.downloadManager.download(video),
              );
          }
        },
      );
    });
  }

  Widget _buildProgressBar() {
    return Observer(builder: (_) {
      return Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
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
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                Text(_fmt(widget.controller.duration),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildControls() {
    return Observer(builder: (_) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: 36,
            onTap: widget.controller.skipToPrevious,
          ),
          GestureDetector(
            onTap: widget.controller.togglePlayPause,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: widget.controller.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      ),
                    )
                  : Icon(
                      widget.controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.black,
                    ),
            ),
          ),
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 36,
            onTap: widget.controller.skipToNext,
          ),
        ],
      );
    });
  }

  Widget _buildSuggestions() {
    return Observer(builder: (_) {
      final suggestions = widget.controller.suggestions;
      final loading = widget.controller.isSuggestionsLoading;

      if (loading && suggestions.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
              child: Text('A seguir',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const LinearProgressIndicator(
              color: Color(0xFFE8432A),
              backgroundColor: Color(0xFF2A2A2A),
              minHeight: 2,
            ),
          ],
        );
      }

      if (suggestions.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Text('A seguir',
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final video = suggestions[index];
              return Observer(
                builder: (_) => VideoCard(
                  video: video,
                  isCurrentlyPlaying: widget.controller.isCurrentVideo(video.id),
                  onTap: () => widget.controller.advanceInQueue(video),
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// LRC parsing
// ---------------------------------------------------------------------------

class _LrcLine {
  final Duration time;
  final String text;
  const _LrcLine(this.time, this.text);
}

List<_LrcLine> _parseLrc(String lrc) {
  final lines = <_LrcLine>[];
  final re = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
  for (final line in lrc.split('\n')) {
    final m = re.firstMatch(line);
    if (m == null) continue;
    final min = int.parse(m.group(1)!);
    final sec = int.parse(m.group(2)!);
    final msStr = m.group(3)!.padRight(3, '0').substring(0, 3);
    final ms = int.parse(msStr);
    final text = m.group(4)!.trim();
    if (text.isEmpty) continue;
    lines.add(_LrcLine(Duration(minutes: min, seconds: sec, milliseconds: ms), text));
  }
  return lines;
}

// ---------------------------------------------------------------------------
// Synced lyrics view
// ---------------------------------------------------------------------------

class _SyncedLyricsView extends StatefulWidget {
  final List<_LrcLine> lines;
  final Duration position;

  const _SyncedLyricsView({super.key, required this.lines, required this.position});

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys;
  int _lastScrolledIdx = -1;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.lines.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _currentIndex() {
    int idx = 0;
    for (int i = 0; i < widget.lines.length; i++) {
      if (widget.lines[i].time <= widget.position) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _scrollToIndex(int idx) {
    if (idx == _lastScrolledIdx) return;
    _lastScrolledIdx = idx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[idx].currentContext;
      if (ctx != null && _scroll.hasClients) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(_SyncedLyricsView old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position) {
      _scrollToIndex(_currentIndex());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex();
    _scrollToIndex(currentIdx);

    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.22,
        horizontal: 24,
      ),
      child: Column(
        children: [
          for (int i = 0; i < widget.lines.length; i++)
            Container(
              key: _keys[i],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: i == currentIdx ? 20 : 15,
                  fontWeight: i == currentIdx ? FontWeight.w700 : FontWeight.w400,
                  color: i == currentIdx ? Colors.white : Colors.white30,
                  height: 1.35,
                ),
                child: Text(widget.lines[i].text, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: Colors.white,
      onPressed: onTap,
    );
  }
}
