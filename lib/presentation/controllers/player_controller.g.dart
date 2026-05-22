// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerController on _PlayerController, Store {
  Computed<double>? _$progressComputed;

  @override
  double get progress =>
      (_$progressComputed ??= Computed<double>(() => super.progress,
              name: '_PlayerController.progress'))
          .value;

  late final _$currentVideoAtom =
      Atom(name: '_PlayerController.currentVideo', context: context);

  @override
  VideoModel? get currentVideo {
    _$currentVideoAtom.reportRead();
    return super.currentVideo;
  }

  @override
  set currentVideo(VideoModel? value) {
    _$currentVideoAtom.reportWrite(value, super.currentVideo, () {
      super.currentVideo = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_PlayerController.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_PlayerController.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$isPlayingAtom =
      Atom(name: '_PlayerController.isPlaying', context: context);

  @override
  bool get isPlaying {
    _$isPlayingAtom.reportRead();
    return super.isPlaying;
  }

  @override
  set isPlaying(bool value) {
    _$isPlayingAtom.reportWrite(value, super.isPlaying, () {
      super.isPlaying = value;
    });
  }

  late final _$positionAtom =
      Atom(name: '_PlayerController.position', context: context);

  @override
  Duration get position {
    _$positionAtom.reportRead();
    return super.position;
  }

  @override
  set position(Duration value) {
    _$positionAtom.reportWrite(value, super.position, () {
      super.position = value;
    });
  }

  late final _$durationAtom =
      Atom(name: '_PlayerController.duration', context: context);

  @override
  Duration get duration {
    _$durationAtom.reportRead();
    return super.duration;
  }

  @override
  set duration(Duration value) {
    _$durationAtom.reportWrite(value, super.duration, () {
      super.duration = value;
    });
  }

  late final _$suggestionsAtom =
      Atom(name: '_PlayerController.suggestions', context: context);

  @override
  ObservableList<VideoModel> get suggestions {
    _$suggestionsAtom.reportRead();
    return super.suggestions;
  }

  @override
  set suggestions(ObservableList<VideoModel> value) {
    _$suggestionsAtom.reportWrite(value, super.suggestions, () {
      super.suggestions = value;
    });
  }

  late final _$isSuggestionsLoadingAtom =
      Atom(name: '_PlayerController.isSuggestionsLoading', context: context);

  @override
  bool get isSuggestionsLoading {
    _$isSuggestionsLoadingAtom.reportRead();
    return super.isSuggestionsLoading;
  }

  @override
  set isSuggestionsLoading(bool value) {
    _$isSuggestionsLoadingAtom.reportWrite(value, super.isSuggestionsLoading,
        () {
      super.isSuggestionsLoading = value;
    });
  }

  late final _$isVideoModeAtom =
      Atom(name: '_PlayerController.isVideoMode', context: context);

  @override
  bool get isVideoMode {
    _$isVideoModeAtom.reportRead();
    return super.isVideoMode;
  }

  @override
  set isVideoMode(bool value) {
    _$isVideoModeAtom.reportWrite(value, super.isVideoMode, () {
      super.isVideoMode = value;
    });
  }

  late final _$lyricsLoadingAtom =
      Atom(name: '_PlayerController.lyricsLoading', context: context);

  @override
  bool get lyricsLoading {
    _$lyricsLoadingAtom.reportRead();
    return super.lyricsLoading;
  }

  @override
  set lyricsLoading(bool value) {
    _$lyricsLoadingAtom.reportWrite(value, super.lyricsLoading, () {
      super.lyricsLoading = value;
    });
  }

  late final _$lyricsLoadedAtom =
      Atom(name: '_PlayerController.lyricsLoaded', context: context);

  @override
  bool get lyricsLoaded {
    _$lyricsLoadedAtom.reportRead();
    return super.lyricsLoaded;
  }

  @override
  set lyricsLoaded(bool value) {
    _$lyricsLoadedAtom.reportWrite(value, super.lyricsLoaded, () {
      super.lyricsLoaded = value;
    });
  }

  late final _$plainLyricsAtom =
      Atom(name: '_PlayerController.plainLyrics', context: context);

  @override
  String? get plainLyrics {
    _$plainLyricsAtom.reportRead();
    return super.plainLyrics;
  }

  @override
  set plainLyrics(String? value) {
    _$plainLyricsAtom.reportWrite(value, super.plainLyrics, () {
      super.plainLyrics = value;
    });
  }

  late final _$syncedLyricsAtom =
      Atom(name: '_PlayerController.syncedLyrics', context: context);

  @override
  String? get syncedLyrics {
    _$syncedLyricsAtom.reportRead();
    return super.syncedLyrics;
  }

  @override
  set syncedLyrics(String? value) {
    _$syncedLyricsAtom.reportWrite(value, super.syncedLyrics, () {
      super.syncedLyrics = value;
    });
  }

  late final _$loadLyricsAsyncAction =
      AsyncAction('_PlayerController.loadLyrics', context: context);

  @override
  Future<void> loadLyrics(String title, String artist) {
    return _$loadLyricsAsyncAction.run(() => super.loadLyrics(title, artist));
  }

  late final _$loadVideoAsyncAction =
      AsyncAction('_PlayerController.loadVideo', context: context);

  @override
  Future<void> loadVideo(VideoModel video) {
    return _$loadVideoAsyncAction.run(() => super.loadVideo(video));
  }

  late final _$skipToNextAsyncAction =
      AsyncAction('_PlayerController.skipToNext', context: context);

  @override
  Future<void> skipToNext() {
    return _$skipToNextAsyncAction.run(() => super.skipToNext());
  }

  late final _$pauseAsyncAction =
      AsyncAction('_PlayerController.pause', context: context);

  @override
  Future<void> pause() {
    return _$pauseAsyncAction.run(() => super.pause());
  }

  late final _$togglePlayPauseAsyncAction =
      AsyncAction('_PlayerController.togglePlayPause', context: context);

  @override
  Future<void> togglePlayPause() {
    return _$togglePlayPauseAsyncAction.run(() => super.togglePlayPause());
  }

  late final _$seekAsyncAction =
      AsyncAction('_PlayerController.seek', context: context);

  @override
  Future<void> seek(Duration pos) {
    return _$seekAsyncAction.run(() => super.seek(pos));
  }

  late final _$switchToVideoModeAsyncAction =
      AsyncAction('_PlayerController.switchToVideoMode', context: context);

  @override
  Future<void> switchToVideoMode() {
    return _$switchToVideoModeAsyncAction.run(() => super.switchToVideoMode());
  }

  late final _$switchToAudioModeAsyncAction =
      AsyncAction('_PlayerController.switchToAudioMode', context: context);

  @override
  Future<void> switchToAudioMode() {
    return _$switchToAudioModeAsyncAction.run(() => super.switchToAudioMode());
  }

  @override
  String toString() {
    return '''
currentVideo: ${currentVideo},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
isPlaying: ${isPlaying},
position: ${position},
duration: ${duration},
suggestions: ${suggestions},
isSuggestionsLoading: ${isSuggestionsLoading},
isVideoMode: ${isVideoMode},
lyricsLoading: ${lyricsLoading},
lyricsLoaded: ${lyricsLoaded},
plainLyrics: ${plainLyrics},
syncedLyrics: ${syncedLyrics},
progress: ${progress}
    ''';
  }
}
