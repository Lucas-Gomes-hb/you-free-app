import 'package:mobx/mobx.dart';

import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';
import '../../data/models/search_filter_option.dart';

part 'video_search_controller.g.dart';

/// Search in video mode.
///
/// YouTube's refinement chips are not combinable: every chip carries the whole
/// opaque `params` for the request it would issue, valid only in the context it
/// was listed in. So this store keeps exactly one [params] value, the newest
/// one, and re-lists the chips after every choice instead of merging them.
class VideoSearchController = _VideoSearchController
    with _$VideoSearchController;

abstract class _VideoSearchController with Store {
  final ContentSource _source;

  _VideoSearchController(this._source);

  /// Text in the field. Typing only updates this; nothing is thrown away until
  /// the user actually submits, so editing a query keeps the results on screen.
  @observable
  String query = '';

  /// Query the results on screen belong to, empty before the first search.
  @observable
  String submittedQuery = '';

  @observable
  String? params;

  /// Labels of the chips already picked, oldest first, shown as removable
  /// pills. The applied set is tracked here because YouTube does not mark the
  /// active chip in its own response.
  @observable
  ObservableList<String> applied = ObservableList<String>();

  @observable
  ObservableList<SearchFilterOption> filters =
      ObservableList<SearchFilterOption>();

  /// `params` of every chip picked so far, oldest first.
  ///
  /// The values are opaque and cannot be un-picked from each other, so the
  /// history has to be kept: without it, dropping the last chip would have
  /// nothing to fall back to and the search would jump all the way back to the
  /// unrefined listing.
  final List<String> _paramsHistory = [];

  /// Bumped by every request that replaces the results. A response that comes
  /// back after a newer request was issued is dropped instead of overwriting
  /// what the user asked for last.
  int _generation = 0;

  @observable
  ObservableList<VideoModel> results = ObservableList<VideoModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  bool get hasResults => results.isNotEmpty;

  bool get isEmpty =>
      !isLoading &&
      errorMessage == null &&
      results.isEmpty &&
      submittedQuery.isNotEmpty;

  @computed
  bool get hasActiveFilters => applied.isNotEmpty;

  @action
  void setQuery(String value) => query = value;

  /// Runs [query]. A new term starts from a clean slate; re-submitting the same
  /// term keeps the chips in force and only refreshes the results.
  @action
  Future<void> search() async {
    final term = query.trim();
    if (term.isEmpty) return;

    if (term != submittedQuery) {
      submittedQuery = term;
      filters.clear();
      applied.clear();
      _paramsHistory.clear();
      params = null;
      results.clear();
    }
    await _run('Não foi possível buscar vídeos');
  }

  /// Picks one chip. The chosen value replaces [params] outright, since it
  /// already encodes everything applied so far.
  @action
  Future<void> applyFilter(SearchFilterOption option) async {
    if (isLoading) return;
    _paramsHistory.add(option.value);
    params = option.value;
    applied.add(option.label);
    // The chips on offer were only valid for the previous listing.
    filters.clear();
    results.clear();
    await _run('Não foi possível aplicar o filtro');
  }

  @action
  Future<void> removeLastFilter() async {
    if (applied.isEmpty || isLoading) return;
    applied.removeLast();
    _paramsHistory.removeLast();
    // Falls back to the value in force before the chip that was just dropped,
    // which is what makes the pills read as a stack rather than a set.
    params = _paramsHistory.isEmpty ? null : _paramsHistory.last;
    filters.clear();
    results.clear();
    await _run('Não foi possível remover o filtro');
  }

  /// Fetches the results for [submittedQuery] and [params], then re-lists the
  /// chips for them.
  ///
  /// The bar has to be re-listed after every change: each chip is only valid in
  /// the context it was offered in. It loads after the results are on screen,
  /// so a slow chip request never holds the list back.
  Future<void> _run(String failureMessage) async {
    final gen = ++_generation;
    final term = submittedQuery;
    final requestParams = params;
    isLoading = true;
    errorMessage = null;
    try {
      final videos = await _source.searchVideos(term, params: requestParams);
      if (gen != _generation) return;
      results = ObservableList.of(videos);
    } catch (e) {
      if (gen != _generation) return;
      errorMessage = failureMessage;
      return;
    } finally {
      if (gen == _generation) isLoading = false;
    }

    try {
      final options =
          await _source.getSearchFilters(term, params: requestParams);
      if (gen != _generation) return;
      filters = ObservableList.of(options);
    } catch (_) {
      // A missing chip bar is not a failure: the results are still valid.
    }
  }

  @action
  void clear() {
    _generation++;
    query = '';
    submittedQuery = '';
    params = null;
    _paramsHistory.clear();
    applied.clear();
    filters.clear();
    results.clear();
    isLoading = false;
    errorMessage = null;
  }
}
