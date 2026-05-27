import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/models/video_model.dart';
import '../data/models/collection_model.dart';
import '../data/services/api_service.dart';
import '../data/services/download_manager.dart';
import '../data/services/settings_service.dart';
import '../data/services/playlist_service.dart';
import '../data/repositories/video_repository.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/player_page.dart';
import '../presentation/pages/collection_page.dart';
import '../presentation/pages/settings_page.dart';
import '../presentation/pages/playlists_page.dart';
import '../presentation/pages/playlist_detail_page.dart';
import '../presentation/components/mini_player.dart';
import '../presentation/controllers/home_controller.dart';
import '../presentation/controllers/player_controller.dart';

class AppRouter {
  final HomeController homeController;
  final PlayerController playerController;
  final DownloadManager downloadManager;
  final ApiService apiService;
  final SettingsService settingsService;
  final VideoRepository videoRepository;
  final PlaylistService playlistService;
  final ValueNotifier<bool> pipModeNotifier;

  AppRouter({
    required this.homeController,
    required this.playerController,
    required this.downloadManager,
    required this.apiService,
    required this.settingsService,
    required this.videoRepository,
    required this.playlistService,
    required this.pipModeNotifier,
  });

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _MainShell(
          navigationShell: navigationShell,
          playerController: playerController,
          onHomeTap: () => homeController.clearSearch(),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => HomePage(
                controller: homeController,
                playerController: playerController,
                onSettings: () => context.push('/settings'),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/playlists',
              builder: (context, state) => PlaylistsPage(
                playlistService: playlistService,
                playerController: playerController,
                videoRepository: videoRepository,
                downloadManager: downloadManager,
              ),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final video = state.extra as VideoModel;
          return PlayerPage(
            controller: playerController,
            downloadManager: downloadManager,
            video: video,
            pipModeNotifier: pipModeNotifier,
          );
        },
      ),
      GoRoute(
        path: '/collection',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CollectionPage(
            collection: extra['collection'] as CollectionModel,
            playerController: extra['playerController'] as PlayerController,
          );
        },
      ),
      GoRoute(
        path: '/playlist-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PlaylistDetailPage(
            playlistId: extra['playlistId'] as String,
            playlistService: extra['playlistService'] as PlaylistService,
            playerController: extra['playerController'] as PlayerController,
            videoRepository: extra['videoRepository'] as VideoRepository,
            downloadManager: extra['downloadManager'] as DownloadManager?,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsPage(
          apiService: apiService,
          settingsService: settingsService,
        ),
      ),
    ],
  );
}

class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final PlayerController playerController;
  final VoidCallback? onHomeTap;

  const _MainShell({
    required this.navigationShell,
    required this.playerController,
    this.onHomeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(controller: playerController),
          BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (i) {
              if (i == 0) onHomeTap?.call();
              navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              );
            },
            backgroundColor: const Color(0xFF0A0A0A),
            selectedItemColor: const Color(0xFFE8432A),
            unselectedItemColor: const Color(0xFF666666),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_rounded),
                label: 'Playlists',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
