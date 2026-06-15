import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../app/theme.dart';
import '../controllers/player_controller.dart';

/// YouTube-style video surface. Draws tap-to-reveal controls (play/pause,
/// ±10 s seek, scrubber and fullscreen toggle) on top of the active
/// [VideoPlayerController] owned by [PlayerController].
///
/// This widget is video-mode only — it never touches the audio/artwork path.
/// The same controller instance is reused inline and in [FullscreenVideoPage],
/// so toggling fullscreen never re-buffers the stream.
class VideoPlayerView extends StatefulWidget {
  final PlayerController controller;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  const VideoPlayerView({
    super.key,
    required this.controller,
    required this.onToggleFullscreen,
    this.fullscreen = false,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  bool _controlsVisible = true;
  bool _scrubbing = false;
  Duration _scrubTarget = Duration.zero;
  Timer? _hideTimer;

  VideoPlayerController? get _vc => widget.controller.videoController;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_vc?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _keepControlsVisible() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  Future<void> _togglePlay() async {
    await widget.controller.togglePlayPause();
    _keepControlsVisible();
  }

  Future<void> _seekBy(int seconds) async {
    final vc = _vc;
    if (vc == null) return;
    final target = vc.value.position + Duration(seconds: seconds);
    final dur = vc.value.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > dur ? dur : target);
    await widget.controller.seek(clamped);
    _keepControlsVisible();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    if (vc == null) {
      return _frame(
        Center(
          child: CircularProgressIndicator(color: context.c.primary, strokeWidth: 2),
        ),
      );
    }
    return _frame(
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: vc,
        builder: (context, value, _) {
          final ar = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: ar,
                  child: value.isInitialized
                      ? VideoPlayer(vc)
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTapDown: (d) {
                    final w = context.size?.width ?? 0;
                    _seekBy(d.localPosition.dx < w / 2 ? -10 : 10);
                  },
                  onDoubleTap: () {},
                ),
              ),
              _buildOverlay(value),
            ],
          );
        },
      ),
    );
  }

  /// Styled box for inline mode; bare black fill in fullscreen.
  Widget _frame(Widget child) {
    if (widget.fullscreen) {
      return Container(color: Colors.black, child: child);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          final vc = _vc;
          final ar = (vc?.value.isInitialized ?? false) && vc!.value.aspectRatio > 0
              ? vc.value.aspectRatio
              : 16 / 9;
          return Container(
            width: width,
            height: width / ar,
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
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlay(VideoPlayerValue value) {
    final pos = _scrubbing ? _scrubTarget : value.position;
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
                Colors.black.withValues(alpha: 0.55),
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
                    _circleButton(Icons.replay_10_rounded, 26, () => _seekBy(-10)),
                    const SizedBox(width: 28),
                    value.isBuffering
                        ? const SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3),
                              ),
                            ),
                          )
                        : _circleButton(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            42,
                            _togglePlay,
                            big: true,
                          ),
                    const SizedBox(width: 28),
                    _circleButton(Icons.forward_10_rounded, 26, () => _seekBy(10)),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  left: widget.fullscreen,
                  right: widget.fullscreen,
                  bottom: widget.fullscreen,
                  child: _buildBottomBar(pos, value.duration),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, double size, VoidCallback onTap,
      {bool big = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: big ? 64 : 48,
        height: big ? 64 : 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildBottomBar(Duration pos, Duration dur) {
    final maxMs = dur.inMilliseconds.toDouble();
    final sliderValue = maxMs <= 0
        ? 0.0
        : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, widget.fullscreen ? 6 : 2),
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
                await widget.controller.seek(Duration(milliseconds: v.toInt()));
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
                Text(_fmt(dur),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onToggleFullscreen,
                  child: Icon(
                    widget.fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Landscape, immersive fullscreen host. Reuses the same [VideoPlayerController]
/// so playback continues seamlessly when entering/leaving fullscreen.
class FullscreenVideoPage extends StatefulWidget {
  final PlayerController controller;

  const FullscreenVideoPage({super.key, required this.controller});

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
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
      body: VideoPlayerView(
        controller: widget.controller,
        fullscreen: true,
        onToggleFullscreen: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
