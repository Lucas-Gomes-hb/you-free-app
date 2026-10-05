import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/video_playback_controller.dart';

/// YouTube-style video surface for the Watch page.
///
/// Draws its own controls — tap to reveal, ±10 s, scrubber, quality menu,
/// speed, Picture-in-Picture — over whatever engine
/// [VideoPlaybackController] picked, so ExoPlayer and video_player look and
/// behave the same. Features the active engine cannot do (quality on a single
/// source, PiP off Android) are hidden rather than shown broken.
class VideoPlayerSurface extends StatefulWidget {
  final VideoPlaybackController controller;
  final VoidCallback onToggleFullscreen;

  /// False draws the bare picture, for Picture-in-Picture and the mini player.
  final bool showControls;

  const VideoPlayerSurface({
    super.key,
    required this.controller,
    required this.onToggleFullscreen,
    this.showControls = true,
  });

  @override
  State<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<VideoPlayerSurface> {
  bool _controlsVisible = true;
  bool _scrubbing = false;
  Duration _scrubTarget = Duration.zero;
  Timer? _hideTimer;

  /// Owned per surface so the inline, fullscreen and mini player surfaces
  /// never share one GlobalKey, which Flutter rejects while both are mounted.
  final GlobalKey _surfaceKey = GlobalKey();

  /// Play state the auto-hide timer was last armed for.
  bool _wasPlaying = false;

  VideoPlaybackController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onPlayback);
    _wasPlaying = _c.isPlaying;
    _scheduleHide();
  }

  @override
  void didUpdateWidget(VideoPlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onPlayback);
      widget.controller.addListener(_onPlayback);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.removeListener(_onPlayback);
    super.dispose();
  }

  /// The controller notifies every second while playing, so re-arming the
  /// auto-hide timer on each notification kept it from ever firing. Only a
  /// change of play state re-arms it: starting playback hides the controls,
  /// pausing keeps them up.
  void _onPlayback() {
    if (!mounted) return;
    setState(() {});
    if (_c.isPlaying != _wasPlaying) {
      _wasPlaying = _c.isPlaying;
      if (_wasPlaying) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        if (!_controlsVisible) setState(() => _controlsVisible = true);
      }
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.isPlaying && !_scrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _keepControlsVisible() {
    if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showControls) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _c.aspectRatio,
              child: _c.buildSurface(_surfaceKey),
            ),
          ),
          if (_c.showsSpinner)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _controlsVisible = !_controlsVisible);
        if (_controlsVisible) _scheduleHide();
      },
      onDoubleTapDown: (d) {
        final w = context.size?.width ?? 0;
        _c.seekBy(Duration(seconds: d.localPosition.dx < w / 2 ? -10 : 10));
      },
      onDoubleTap: () {},
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _c.aspectRatio,
              child: _buildSurface(),
            ),
          ),
          // The error panel carries its own retry, and the transport row would
          // sit right on top of it.
          if (_c.error == null) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildSurface() {
    if (_c.error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white54, size: 34),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _c.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _c.retry,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Tentar novamente',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    return _c.buildSurface(_surfaceKey);
  }

  Widget _buildOverlay() {
    final pos = _scrubbing ? _scrubTarget : _c.position;
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleButton(Icons.replay_10_rounded, 30,
                        () => _c.seekBy(const Duration(seconds: -10))),
                    SizedBox(width: 32 * _controlScale),
                    if (_c.showsSpinner)
                      SizedBox(
                        width: 76 * _controlScale,
                        height: 76 * _controlScale,
                        child: Center(
                          child: SizedBox(
                            width: 44 * _controlScale,
                            height: 44 * _controlScale,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                        ),
                      )
                    else
                      _circleButton(
                        _c.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        48,
                        () {
                          _c.togglePlayPause();
                          _keepControlsVisible();
                        },
                        big: true,
                      ),
                    SizedBox(width: 32 * _controlScale),
                    _circleButton(Icons.forward_10_rounded, 30,
                        () => _c.seekBy(const Duration(seconds: 10))),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: _buildBottomBar(pos)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grows the transport controls on wider screens: the sizes are tuned for a
  /// ~411dp phone and read as cramped on the 432dp handsets, where the video
  /// box is also proportionally bigger.
  double get _controlScale =>
      (MediaQuery.sizeOf(context).width / 411).clamp(0.92, 1.18);

  Widget _circleButton(
    IconData icon,
    double size,
    VoidCallback onTap, {
    bool big = false,
  }) {
    final s = _controlScale;
    final d = (big ? 76 : 56) * s;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // The visual circle stays put, the hit area grows past the 48dp
        // minimum every platform asks for.
        width: d < 48 ? 48 : d,
        height: d < 48 ? 48 : d,
        child: Center(
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * s),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Duration pos) {
    final dur = _c.duration;
    final maxMs = dur.inMilliseconds.toDouble();
    final sliderValue = maxMs <= 0
        ? 0.0
        : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: context.c.primary,
              inactiveTrackColor: Colors.white30,
              thumbColor: context.c.primary,
              overlayColor: context.c.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: 0,
              max: maxMs <= 0 ? 1 : maxMs,
              value: sliderValue.clamp(0, maxMs <= 0 ? 1 : maxMs),
              onChangeStart: (v) {
                setState(() {
                  _scrubbing = true;
                  _scrubTarget = Duration(milliseconds: v.toInt());
                });
                _hideTimer?.cancel();
              },
              onChanged: (v) {
                setState(() => _scrubTarget = Duration(milliseconds: v.toInt()));
              },
              onChangeEnd: (v) async {
                await _c.seek(Duration(milliseconds: v.toInt()));
                if (mounted) setState(() => _scrubbing = false);
                _scheduleHide();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(_fmt(pos),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                const Spacer(),
                if (_c.qualities.isNotEmpty)
                  _pillButton(
                    _c.activeQuality ?? 'Auto',
                    Icons.high_quality_rounded,
                    _showQualityMenu,
                  ),
                _pillButton(
                  '${_c.speed}x',
                  Icons.speed_rounded,
                  _c.cycleSpeed,
                ),
                if (_c.supportsPictureInPicture)
                  _iconButton(Icons.picture_in_picture_alt_rounded,
                      _c.enterPictureInPicture),
                Text(_fmt(dur),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 10),
                _iconButton(Icons.fullscreen_rounded, widget.onToggleFullscreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    final s = _controlScale;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40 * s,
        height: 40 * s,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 24 * s),
        ),
      ),
    );
  }

  /// Tap target that opens a menu, as opposed to the icon buttons that act
  /// immediately. A pill because the value itself is the label.
  Widget _pillButton(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          onTap();
          _keepControlsVisible();
        },
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5)),
            ],
          ),
        ),
      );

  void _showQualityMenu() {
    _keepControlsVisible();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Qualidade',
                    style: TextStyle(
                        color: context.c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            ..._c.qualities.map((PlaybackQuality q) {
              // Auto is the DASH default: nothing is pinned, so it is the one
              // entry that reads as selected when no rung was chosen.
              final selected = q.isAuto
                  ? _c.activeQuality == null
                  : q.label == _c.activeQuality;
              return ListTile(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _c.setQuality(q);
                },
                title: Text(
                  q.label,
                  style: TextStyle(
                    color: selected ? context.c.primary : context.c.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: q.resolution?.filesize != null
                    ? Text(_humanSize(q.resolution!.filesize!),
                        style: TextStyle(color: context.c.textMuted, fontSize: 12))
                    : null,
                trailing: selected
                    ? Icon(Icons.check_rounded, color: context.c.primary)
                    : null,
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _humanSize(int bytes) {
    if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
