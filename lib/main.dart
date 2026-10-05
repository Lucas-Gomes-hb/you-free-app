import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mobx/mobx.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'app/theme_controller.dart';
import 'data/services/api_service.dart';
import 'data/services/history_service.dart';
import 'data/services/audio_handler.dart';
import 'data/services/download_manager.dart';
import 'data/services/settings_service.dart';
import 'data/services/progress_service.dart';
import 'data/services/playlist_service.dart';
import 'data/services/repertoire_service.dart';
import 'data/repositories/video_repository.dart';
import 'presentation/controllers/home_controller.dart';
import 'presentation/controllers/player_controller.dart';
import 'presentation/controllers/video_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.load();

  final themeController = ThemeController();
  await themeController.load();

  final audioHandler = await AudioService.init<YouFreeAudioHandler>(
    builder: () => YouFreeAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.example.youfree.audio',
      androidNotificationChannelName: 'YouFree',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );

  runApp(YouFreeApp(
    audioHandler: audioHandler,
    settingsService: settingsService,
    themeController: themeController,
  ));
}

class YouFreeApp extends StatefulWidget {
  final YouFreeAudioHandler audioHandler;
  final SettingsService settingsService;
  final ThemeController themeController;

  const YouFreeApp({
    Key? key,
    required this.audioHandler,
    required this.settingsService,
    required this.themeController,
  }) : super(key: key);

  @override
  _YouFreeAppState createState() => _YouFreeAppState();
}

class _YouFreeAppState extends State<YouFreeApp> {
  late final ApiService _apiService;
  late final VideoRepository _videoRepository;
  late final HistoryService _historyService;
  late final DownloadManager _downloadManager;
  late final HomeController _homeController;
  late final PlayerController _playerController;
  late final PlaylistService _playlistService;
  late final RepertoireService _repertoireService;
  late final VideoSessionController _videoSession;
  late final AppRouter _appRouter;

  final _pipModeNotifier = ValueNotifier<bool>(false);
  static const _pipChannel = MethodChannel('com.example.youfree/pip');
  /// Set when the activity leaves PiP until the app settles: back in the
  /// foreground means the window was expanded, hidden means it was closed.
  bool _pipExitPending = false;
  AppLifecycleListener? _lifecycleListener;
  ReactionDisposer? _pipReactionDisposer;
  bool _videoWasPlaying = false;
  bool _autoPip = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      widget.settingsService.apiUrl,
      mode: widget.settingsService.contentMode,
    );
    _apiService.setAppMode(widget.settingsService.appMode);
    _videoRepository = VideoRepository(_apiService);
    _historyService = HistoryService();
    _homeController = HomeController(_videoRepository, _historyService);
    _playlistService = PlaylistService();
    _downloadManager = DownloadManager(_apiService, _playlistService);
    _playlistService.load().then((_) => _downloadManager.syncToPlaylists());
    _repertoireService = RepertoireService(_playlistService, widget.settingsService);
    _playerController = PlayerController(
      _videoRepository,
      _historyService,
      widget.audioHandler,
      ProgressService(),
      _downloadManager,
      _repertoireService,
    );
    _playerController.onVideoLoaded = _homeController.onVideoPlayed;
    _homeController.loadHistory();

    _videoSession = VideoSessionController(
      source: _apiService,
      playerController: _playerController,
      historyService: _historyService,
      pipMode: _pipModeNotifier,
      onWatched: _homeController.onVideoPlayed,
    );
    _videoSession.playback.onPictureInPicture = _enterVideoPip;
    _videoSession.playback.addListener(_onVideoPlayback);
    _videoSession.addListener(_syncAutoPip);
    // Video mode is the only place the session can be reached from; switching
    // back to music must not leave a minimized video behind.
    widget.settingsService.addListener(_onSettingsChanged);

    // Direct callback from AudioHandler — fires on every play/pause regardless of source.
    // This keeps PiP icon in sync with the notification (same data path).
    widget.audioHandler.onPlayingChanged = (playing) {
      if (_videoSession.isActive) return;
      _pipChannel.invokeMethod('updatePipState', playing);
    };

    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipModeChanged':
          final entering = call.arguments as bool;
          final wasInPip = _pipModeNotifier.value;
          _pipModeNotifier.value = entering;
          // Leaving PiP is either expanding or closing the window, and only
          // the state the app settles in tells them apart: it can sit
          // inactive for well over half a second before resuming, so a timer
          // paused playback the user had just expanded.
          // Closing can also report the other way round: hidden first, the
          // mode change after, with no lifecycle change left to wait for.
          if (wasInPip && !entering) {
            final state = WidgetsBinding.instance.lifecycleState;
            if (state == AppLifecycleState.hidden ||
                state == AppLifecycleState.paused) {
              _pipExitPending = false;
              _pauseActivePlayback();
            } else {
              _pipExitPending = state != AppLifecycleState.resumed;
            }
          }
        case 'pipExpanded':
          _pipExitPending = false;
        case 'pipPlayPause':
          // Send optimistic update immediately so the PiP icon feels instant,
          // then let the handler confirm via onPlayingChanged.
          if (_videoSession.isActive) {
            _pipChannel.invokeMethod(
                'updatePipState', !_videoSession.playback.isPlaying);
            await _videoSession.togglePlayPause();
          } else {
            _pipChannel.invokeMethod(
                'updatePipState', !_playerController.isPlaying);
            await _playerController.togglePlayPause();
          }
      }
    });

    // Keep MobX reaction as secondary sync (covers video-mode toggles via VideoPlayerController)
    _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycle);

    _pipReactionDisposer = reaction(
      (_) => _playerController.isPlaying,
      (bool playing) {
        if (_videoSession.isActive) return;
        _pipChannel.invokeMethod('updatePipState', playing);
      },
    );

    _appRouter = AppRouter(
      homeController: _homeController,
      playerController: _playerController,
      downloadManager: _downloadManager,
      apiService: _apiService,
      settingsService: widget.settingsService,
      videoRepository: _videoRepository,
      playlistService: _playlistService,
      pipModeNotifier: _pipModeNotifier,
      themeController: widget.themeController,
      videoSession: _videoSession,
    );
  }

  void _onLifecycle(AppLifecycleState state) {
    if (!_pipExitPending) return;
    if (state == AppLifecycleState.resumed) {
      _pipExitPending = false;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _pipExitPending = false;
      _pauseActivePlayback();
    }
  }

  void _pauseActivePlayback() {
    if (_videoSession.isActive) {
      _videoSession.pause();
    } else {
      _playerController.pause();
    }
  }

  Future<void> _enterVideoPip() async {
    try {
      await _pipChannel.invokeMethod(
          'updatePipState', _videoSession.playback.isPlaying);
      await _pipChannel.invokeMethod('enterPip', null);
    } catch (_) {}
  }

  /// Keeps the PiP play/pause action on the video while a session is open.
  void _onVideoPlayback() {
    final playing = _videoSession.playback.isPlaying;
    if (playing != _videoWasPlaying) {
      _videoWasPlaying = playing;
      if (_videoSession.isActive) {
        _pipChannel.invokeMethod('updatePipState', playing);
      }
    }
    _syncAutoPip();
  }

  /// Leaving the app with a video playing on the Watch page drops it into
  /// Picture-in-Picture, like YouTube, instead of stopping it.
  void _syncAutoPip() {
    final enabled = _videoSession.isWatchPageOpen &&
        _videoSession.playback.isPlaying &&
        _videoSession.playback.supportsPictureInPicture;
    if (enabled == _autoPip) return;
    _autoPip = enabled;
    _pipChannel.invokeMethod('setAutoPip', enabled).catchError((_) {});
  }

  void _onSettingsChanged() {
    if (widget.settingsService.profile.isMusic) _videoSession.close();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _pipReactionDisposer?.call();
    widget.settingsService.removeListener(_onSettingsChanged);
    _videoSession.playback.removeListener(_onVideoPlayback);
    _videoSession.removeListener(_syncAutoPip);
    _videoSession.dispose();
    _pipModeNotifier.dispose();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return App(appRouter: _appRouter, themeController: widget.themeController);
  }
}
