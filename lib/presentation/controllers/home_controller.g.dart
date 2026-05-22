// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HomeController on _HomeController, Store {
  late final _$searchQueryAtom =
      Atom(name: '_HomeController.searchQuery', context: context);

  @override
  String get searchQuery {
    _$searchQueryAtom.reportRead();
    return super.searchQuery;
  }

  @override
  set searchQuery(String value) {
    _$searchQueryAtom.reportWrite(value, super.searchQuery, () {
      super.searchQuery = value;
    });
  }

  late final _$searchTypeAtom =
      Atom(name: '_HomeController.searchType', context: context);

  @override
  SearchType get searchType {
    _$searchTypeAtom.reportRead();
    return super.searchType;
  }

  @override
  set searchType(SearchType value) {
    _$searchTypeAtom.reportWrite(value, super.searchType, () {
      super.searchType = value;
    });
  }

  late final _$videosAtom =
      Atom(name: '_HomeController.videos', context: context);

  @override
  ObservableList<VideoModel> get videos {
    _$videosAtom.reportRead();
    return super.videos;
  }

  @override
  set videos(ObservableList<VideoModel> value) {
    _$videosAtom.reportWrite(value, super.videos, () {
      super.videos = value;
    });
  }

  late final _$channelsAtom =
      Atom(name: '_HomeController.channels', context: context);

  @override
  ObservableList<ChannelInfo> get channels {
    _$channelsAtom.reportRead();
    return super.channels;
  }

  @override
  set channels(ObservableList<ChannelInfo> value) {
    _$channelsAtom.reportWrite(value, super.channels, () {
      super.channels = value;
    });
  }

  late final _$playlistsAtom =
      Atom(name: '_HomeController.playlists', context: context);

  @override
  ObservableList<PlaylistPreview> get playlists {
    _$playlistsAtom.reportRead();
    return super.playlists;
  }

  @override
  set playlists(ObservableList<PlaylistPreview> value) {
    _$playlistsAtom.reportWrite(value, super.playlists, () {
      super.playlists = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_HomeController.isLoading', context: context);

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
      Atom(name: '_HomeController.errorMessage', context: context);

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

  late final _$recentlyPlayedAtom =
      Atom(name: '_HomeController.recentlyPlayed', context: context);

  @override
  ObservableList<VideoModel> get recentlyPlayed {
    _$recentlyPlayedAtom.reportRead();
    return super.recentlyPlayed;
  }

  @override
  set recentlyPlayed(ObservableList<VideoModel> value) {
    _$recentlyPlayedAtom.reportWrite(value, super.recentlyPlayed, () {
      super.recentlyPlayed = value;
    });
  }

  late final _$searchAsyncAction =
      AsyncAction('_HomeController.search', context: context);

  @override
  Future<void> search() {
    return _$searchAsyncAction.run(() => super.search());
  }

  late final _$searchChannelsAsyncAction =
      AsyncAction('_HomeController.searchChannels', context: context);

  @override
  Future<void> searchChannels() {
    return _$searchChannelsAsyncAction.run(() => super.searchChannels());
  }

  late final _$searchPlaylistsAsyncAction =
      AsyncAction('_HomeController.searchPlaylists', context: context);

  @override
  Future<void> searchPlaylists() {
    return _$searchPlaylistsAsyncAction.run(() => super.searchPlaylists());
  }

  late final _$loadHistoryAsyncAction =
      AsyncAction('_HomeController.loadHistory', context: context);

  @override
  Future<void> loadHistory() {
    return _$loadHistoryAsyncAction.run(() => super.loadHistory());
  }

  late final _$_HomeControllerActionController =
      ActionController(name: '_HomeController', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_HomeControllerActionController.startAction(
        name: '_HomeController.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_HomeControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSearchType(SearchType type) {
    final _$actionInfo = _$_HomeControllerActionController.startAction(
        name: '_HomeController.setSearchType');
    try {
      return super.setSearchType(type);
    } finally {
      _$_HomeControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSearch() {
    final _$actionInfo = _$_HomeControllerActionController.startAction(
        name: '_HomeController.clearSearch');
    try {
      return super.clearSearch();
    } finally {
      _$_HomeControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
searchQuery: ${searchQuery},
searchType: ${searchType},
videos: ${videos},
channels: ${channels},
playlists: ${playlists},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
recentlyPlayed: ${recentlyPlayed}
    ''';
  }
}
