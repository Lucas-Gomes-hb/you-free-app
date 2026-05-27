import 'package:mobx/mobx.dart';
import '../../data/models/video_model.dart';
import '../../data/models/collection_model.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/history_service.dart';
import '../../data/services/search_history_service.dart';

part 'home_controller.g.dart';

enum SearchType { videos, artists, albums }

class HomeController = _HomeController with _$HomeController;

abstract class _HomeController with Store {
  final VideoRepository _repository;
  final HistoryService _historyService;
  final SearchHistoryService _searchHistoryService = SearchHistoryService();

  _HomeController(this._repository, this._historyService);

  @observable
  String searchQuery = '';

  @observable
  SearchType searchType = SearchType.videos;

  @observable
  ObservableList<VideoModel> videos = ObservableList<VideoModel>();

  @observable
  ObservableList<ChannelInfo> channels = ObservableList<ChannelInfo>();

  @observable
  ObservableList<PlaylistPreview> playlists = ObservableList<PlaylistPreview>();

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingMoreSearch = false;

  @observable
  String? errorMessage;

  @observable
  ObservableList<VideoModel> recentlyPlayed = ObservableList<VideoModel>();

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setSearchType(SearchType type) {
    searchType = type;
    if (searchQuery.trim().isNotEmpty) {
      if (type == SearchType.artists) {
        searchChannels();
      } else if (type == SearchType.albums) {
        searchPlaylists();
      } else {
        search();
      }
    }
  }

  @action
  Future<void> search() async {
    if (searchQuery.trim().isEmpty) return;

    await _searchHistoryService.add(searchQuery.trim());

    isLoading = true;
    errorMessage = null;
    videos.clear();
    channels.clear();
    playlists.clear();

    try {
      final results = await _repository.searchVideos(searchQuery);
      videos = ObservableList.of(results);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadMoreSearch() async {
    if (searchQuery.trim().isEmpty || isLoadingMoreSearch || isLoading) return;
    if (channels.isNotEmpty || playlists.isNotEmpty) return;

    isLoadingMoreSearch = true;
    try {
      final more = await _repository.searchVideos(searchQuery, offset: videos.length);
      final seen = videos.map((v) => v.id).toSet();
      final fresh = more.where((v) => !seen.contains(v.id)).toList();
      if (fresh.isNotEmpty) videos.addAll(fresh);
    } catch (_) {
    } finally {
      isLoadingMoreSearch = false;
    }
  }

  @action
  Future<void> searchChannels() async {
    if (searchQuery.trim().isEmpty) return;

    await _searchHistoryService.add(searchQuery.trim());

    isLoading = true;
    errorMessage = null;
    videos.clear();
    channels.clear();
    playlists.clear();

    try {
      final results = await _repository.searchChannels(searchQuery);
      channels = ObservableList.of(results);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> searchPlaylists() async {
    if (searchQuery.trim().isEmpty) return;

    await _searchHistoryService.add(searchQuery.trim());

    isLoading = true;
    errorMessage = null;
    videos.clear();
    channels.clear();
    playlists.clear();

    try {
      final results = await _repository.searchPlaylists(searchQuery);
      playlists = ObservableList.of(results);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  Future<CollectionModel?> fetchCollection(String url) async {
    runInAction(() {
      isLoading = true;
      errorMessage = null;
      videos.clear();
      channels.clear();
      playlists.clear();
    });
    try {
      final collection = await _repository.getCollection(url);
      runInAction(() { isLoading = false; });
      return collection;
    } catch (e) {
      runInAction(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      return null;
    }
  }

  @action
  void clearSearch() {
    searchQuery = '';
    videos.clear();
    channels.clear();
    playlists.clear();
    errorMessage = null;
    loadHistory();
  }

  @action
  Future<void> loadHistory() async {
    final history = await _historyService.getAll();
    recentlyPlayed = ObservableList.of(history);
  }

  void onVideoPlayed(VideoModel video) {
    loadHistory();
  }

  Future<List<VideoModel>> loadHomeFeed() async {
    return await _repository.getHomeFeed();
  }

  Future<List<VideoModel>> loadMoreFeed(VideoModel seed) async {
    return await _repository.getSuggestions(
      seed.id,
      title: seed.title,
      uploader: seed.uploader ?? '',
    );
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    return await _repository.getSearchSuggestions(query);
  }

  /// Returns history entries matching [prefix], for local autocomplete.
  Future<List<String>> getSearchHistory(String prefix) async {
    return await _searchHistoryService.getMatching(prefix);
  }

  /// Removes a single entry from the local search history.
  Future<void> deleteSearchHistoryEntry(String query) async {
    await _searchHistoryService.remove(query);
  }
}
