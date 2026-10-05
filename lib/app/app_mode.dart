import 'package:flutter/material.dart';

import 'theme.dart';

/// What the app *is*, as opposed to where its data comes from.
///
/// Deliberately orthogonal to `ContentMode`: "run against the API or resolve
/// on-device" is an infrastructure choice, while this is what the user sees.
/// A device can serve both.
enum AppMode {
  music,
  video;

  String get label => switch (this) {
        AppMode.music => 'Música',
        AppMode.video => 'Vídeo',
      };

  String get description => switch (this) {
        AppMode.music =>
          'Feed de músicas, busca por faixas, artistas e álbuns, e player com letra.',
        AppMode.video =>
          'Feed de vídeos, busca com filtros do YouTube, comentários e player de vídeo.',
      };

  IconData get icon => switch (this) {
        AppMode.music => Icons.library_music_rounded,
        AppMode.video => Icons.play_circle_fill_rounded,
      };
}

/// Every per-mode decision, resolved in one place.
///
/// Pages read this instead of branching on [AppMode] themselves, so adding a
/// mode never means hunting `if (isVideo)` through the tree. [SettingsService]
/// is the single source of truth for the current mode; this class stays a
/// stateless lookup so it can be derived anywhere without a listener.
class ModeProfile {
  const ModeProfile._(this.mode);

  final AppMode mode;

  bool get isMusic => mode == AppMode.music;
  bool get isVideo => mode == AppMode.video;

  /// The music-only filter (60s–12m, no "podcast"/"tutorial" titles) is what
  /// makes the catalog musical. Video mode must drop it entirely or a 1:1
  /// YouTube is unreachable — long lectures and streams are legitimate there.
  bool get appliesMusicFilter => isMusic;

  /// Lyrics and albums only exist in the music experience.
  bool get supportsLyrics => isMusic;
  bool get supportsAlbums => isMusic;

  /// Audio-first screens are meaningless in video mode; the music player is
  /// replaced by a full watch page.
  bool get usesAudioPlayer => isMusic;

  /// Music search is grouped by entity kind, matching YouTube Music. Video
  /// search uses YouTube's own refinement chips instead.
  bool get groupsSearchByKind => isMusic;

  /// Both modes browse and search, so the tab exists in each.
  bool get showsSearchTab => true;

  static ModeProfile of(AppMode mode) => ModeProfile._(mode);

  static const music = ModeProfile._(AppMode.music);
  static const video = ModeProfile._(AppMode.video);
}

/// Convenience for theme-scoped widgets that only need the accent of a mode.
extension AppModeTheming on AppMode {
  Color accent(AppPalette palette) =>
      this == AppMode.video ? const Color(0xFFFF0033) : palette.primary;
}
