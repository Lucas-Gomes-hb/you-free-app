import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youfree/app/app_mode.dart';
import 'package:youfree/data/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService app mode', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to music', () async {
      final s = SettingsService();
      await s.load();
      expect(s.appMode, AppMode.music);
    });

    test('persists the selected mode and reloads it', () async {
      final s = SettingsService();
      await s.load();
      await s.setAppMode(AppMode.video);

      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.appMode, AppMode.video);
    });

    test('ignores a redundant set of the same mode', () async {
      final s = SettingsService();
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setAppMode(AppMode.music);
      expect(notified, 0);
    });

    test('notifies listeners when the mode actually changes', () async {
      final s = SettingsService();
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setAppMode(AppMode.video);
      expect(notified, 1);
    });

    test('falls back to the default when the stored value is unknown', () async {
      SharedPreferences.setMockInitialValues({'app_mode': 'nao_existe'});
      final s = SettingsService();
      await s.load();
      expect(s.appMode, AppMode.music);
    });
  });

  group('ModeProfile', () {
    test('music mode is the only one that applies the music filter', () {
      expect(ModeProfile.of(AppMode.music).appliesMusicFilter, isTrue);
      expect(ModeProfile.of(AppMode.video).appliesMusicFilter, isFalse);
    });

    test('both modes browse and search', () {
      for (final mode in AppMode.values) {
        expect(ModeProfile.of(mode).showsSearchTab, isTrue,
            reason: '$mode should expose the search tab');
      }
    });

    test('lyrics and albums belong to the music experience only', () {
      expect(ModeProfile.music.supportsLyrics, isTrue);
      expect(ModeProfile.video.supportsLyrics, isFalse);
      expect(ModeProfile.music.supportsAlbums, isTrue);
      expect(ModeProfile.video.supportsAlbums, isFalse);
    });

    test('each mode exposes a label and description', () {
      for (final mode in AppMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });
}
