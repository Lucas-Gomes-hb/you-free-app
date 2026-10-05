import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_mode.dart';
import 'theme.dart';
import 'theme_controller.dart';
import '../data/models/video_model.dart';
import '../data/models/collection_model.dart';
import '../data/services/api_service.dart';
import '../data/services/download_manager.dart';
import '../data/services/settings_service.dart';
import '../data/services/playlist_service.dart';
import '../data/repositories/video_repository.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/search_page.dart';
import '../presentation/pages/video_home_page.dart';
import '../presentation/pages/video_search_page.dart';
import '../presentation/pages/watch_page.dart';
import '../presentation/pages/player_page.dart';
import '../presentation/pages/collection_page.dart';
import '../presentation/pages/settings_page.dart';
import '../presentation/pages/playlists_page.dart';
import '../presentation/pages/playlist_detail_page.dart';
import '../presentation/components/mini_player.dart';
import '../presentation/controllers/home_controller.dart';
import '../presentation/controllers/player_controller.dart';
import '../presentation/controllers/video_session_controller.dart';

class AppRouter {
  final HomeController homeController;
  final PlayerController playerController;
  final DownloadManager downloadManager;
  final ApiService apiService;
  final SettingsService settingsService;
  final VideoRepository videoRepository;
  final PlaylistService playlistService;
  final ValueNotifier<bool> pipModeNotifier;
  final ThemeController themeController;
  final VideoSessionController videoSession;

  AppRouter({
    required this.homeController,
    required this.playerController,
    required this.downloadManager,
    required this.apiService,
    required this.settingsService,
    required this.videoRepository,
    required this.playlistService,
    required this.pipModeNotifier,
    required this.themeController,
    required this.videoSession,
  });

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: settingsService,
    routes: [
          StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _MainShell(
          navigationShell: navigationShell,
          playerController: playerController,
          videoSession: videoSession,
          profile: settingsService.profile,
          onHomeTap: () => homeController.clearSearch(),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) {
                // The branch is shared, so the page is chosen from the mode
                // rather than duplicated: rebuilding on change keeps the feed
                // that was already loaded in memory.
                return settingsService.profile.isVideo
                    ? VideoHomePage(
                        source: apiService.contentSource,
                        playerController: playerController,
                        onSettings: () => context.push('/settings'),
                      )
                    : HomePage(
                        controller: homeController,
                        playerController: playerController,
                        onSettings: () => context.push('/settings'),
                      );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => settingsService.profile.isVideo
                  ? VideoSearchPage(
                      source: apiService.contentSource,
                      playerController: playerController,
                      onSettings: () => context.push('/settings'),
                    )
                  : SearchPage(
                      controller: homeController,
                      playerController: playerController,
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
        path: '/watch',
        builder: (context, state) => WatchPage(
          video: state.extra as VideoModel,
          session: videoSession,
        ),
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
          themeController: themeController,
          homeController: homeController,
        ),
      ),
    ],
  );
}

class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final PlayerController playerController;
  final VideoSessionController videoSession;
  final ModeProfile profile;
  final VoidCallback? onHomeTap;

  const _MainShell({
    required this.navigationShell,
    required this.playerController,
    required this.videoSession,
    required this.profile,
    this.onHomeTap,
  });

  /// Branch order is fixed (0 home, 1 search, 2 playlists) so the shell's
  /// index stays stable across mode changes; what a branch shows is decided by
  /// the mode, not by which branch it is.
  static const _searchBranch = 1;
  static const _playlistsBranch = 2;

  List<({int branch, BottomNavigationBarItem item})> get _tabs => [
        (
          branch: 0,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
        ),
        (
          branch: _searchBranch,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Busca',
          ),
        ),
        (
          branch: _playlistsBranch,
          item: BottomNavigationBarItem(
            icon: Icon(
              profile.isMusic
                  ? Icons.queue_music_rounded
                  : Icons.playlist_play_rounded,
            ),
            label: 'Playlists',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tabs = _tabs;
    return Scaffold(
      backgroundColor: c.background,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(
            controller: playerController,
            videoSession: videoSession,
          ),
          BottomNavigationBar(
            currentIndex: tabs.indexWhere(
              (t) => t.branch == navigationShell.currentIndex,
            ),
            onTap: (i) {
              final branch = tabs[i].branch;
              if (branch == 0) onHomeTap?.call();
              navigationShell.goBranch(
                branch,
                initialLocation: branch == navigationShell.currentIndex,
              );
            },
            backgroundColor: c.background,
            selectedItemColor: c.primary,
            unselectedItemColor: c.textMuted,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: tabs.map((t) => t.item).toList(),
          ),
        ],
      ),
    );
  }
}
