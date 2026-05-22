import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mobx/mobx.dart';
import 'app/app.dart';
import 'app/router.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.load();

  final audioHandler = await AudioService.init<YouFreeAudioHandler>(
    builder: () => YouFreeAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.example.youfree.audio',
      androidNotificationChannelName: 'YouFree',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );

  runApp(YouFreeApp(audioHandler: audioHandler, settingsService: settingsService));
}

class YouFreeApp extends StatefulWidget {
  final YouFreeAudioHandler audioHandler;
  final SettingsService settingsService;

  const YouFreeApp({Key? key, required this.audioHandler, required this.settingsService})
      : super(key: key);

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
  late final AppRouter _appRouter;

  final _pipModeNotifier = ValueNotifier<bool>(false);
  static const _pipChannel = MethodChannel('com.example.youfree/pip');
  Timer? _pipDismissTimer;
  ReactionDisposer? _pipReactionDisposer;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.settingsService.apiUrl);
    _videoRepository = VideoRepository(_apiService);
    _historyService = HistoryService();
    _homeController = HomeController(_videoRepository, _historyService);
    _playlistService = PlaylistService();
    _downloadManager = DownloadManager(_apiService, _playlistService);
    _playlistService.load().then((_) => _downloadManager.syncToPlaylists());
    _repertoireService = RepertoireService(_playlistService);
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

    // Direct callback from AudioHandler — fires on every play/pause regardless of source.
    // This keeps PiP icon in sync with the notification (same data path).
    widget.audioHandler.onPlayingChanged = (playing) {
      _pipChannel.invokeMethod('updatePipState', playing);
    };

    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipModeChanged':
          final entering = call.arguments as bool;
          final wasInPip = _pipModeNotifier.value;
          _pipModeNotifier.value = entering;
          if (wasInPip && !entering) {
            _pipDismissTimer?.cancel();
            _pipDismissTimer = Timer(const Duration(milliseconds: 600), () {
              _playerController.pause();
            });
          }
        case 'pipExpanded':
          _pipDismissTimer?.cancel();
        case 'pipPlayPause':
          // Send optimistic update immediately so the PiP icon feels instant,
          // then let the handler confirm via onPlayingChanged.
          _pipChannel.invokeMethod('updatePipState', !_playerController.isPlaying);
          await _playerController.togglePlayPause();
      }
    });

    // Keep MobX reaction as secondary sync (covers video-mode toggles via VideoPlayerController)
    _pipReactionDisposer = reaction(
      (_) => _playerController.isPlaying,
      (bool playing) => _pipChannel.invokeMethod('updatePipState', playing),
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
    );
  }

  @override
  void dispose() {
    _pipDismissTimer?.cancel();
    _pipReactionDisposer?.call();
    _pipModeNotifier.dispose();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return App(appRouter: _appRouter);
  }
}
