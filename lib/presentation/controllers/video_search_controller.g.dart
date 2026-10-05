// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_search_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoSearchController on _VideoSearchController, Store {
  Computed<bool>? _$hasActiveFiltersComputed;

  @override
  bool get hasActiveFilters => (_$hasActiveFiltersComputed ??= Computed<bool>(
          () => super.hasActiveFilters,
          name: '_VideoSearchController.hasActiveFilters'))
      .value;

  late final _$queryAtom =
      Atom(name: '_VideoSearchController.query', context: context);

  @override
  String get query {
    _$queryAtom.reportRead();
    return super.query;
  }

  @override
  set query(String value) {
    _$queryAtom.reportWrite(value, super.query, () {
      super.query = value;
    });
  }

  late final _$submittedQueryAtom =
      Atom(name: '_VideoSearchController.submittedQuery', context: context);

  @override
  String get submittedQuery {
    _$submittedQueryAtom.reportRead();
    return super.submittedQuery;
  }

  @override
  set submittedQuery(String value) {
    _$submittedQueryAtom.reportWrite(value, super.submittedQuery, () {
      super.submittedQuery = value;
    });
  }

  late final _$paramsAtom =
      Atom(name: '_VideoSearchController.params', context: context);

  @override
  String? get params {
    _$paramsAtom.reportRead();
    return super.params;
  }

  @override
  set params(String? value) {
    _$paramsAtom.reportWrite(value, super.params, () {
      super.params = value;
    });
  }

  late final _$appliedAtom =
      Atom(name: '_VideoSearchController.applied', context: context);

  @override
  ObservableList<String> get applied {
    _$appliedAtom.reportRead();
    return super.applied;
  }

  @override
  set applied(ObservableList<String> value) {
    _$appliedAtom.reportWrite(value, super.applied, () {
      super.applied = value;
    });
  }

  late final _$filtersAtom =
      Atom(name: '_VideoSearchController.filters', context: context);

  @override
  ObservableList<SearchFilterOption> get filters {
    _$filtersAtom.reportRead();
    return super.filters;
  }

  @override
  set filters(ObservableList<SearchFilterOption> value) {
    _$filtersAtom.reportWrite(value, super.filters, () {
      super.filters = value;
    });
  }

  late final _$resultsAtom =
      Atom(name: '_VideoSearchController.results', context: context);

  @override
  ObservableList<VideoModel> get results {
    _$resultsAtom.reportRead();
    return super.results;
  }

  @override
  set results(ObservableList<VideoModel> value) {
    _$resultsAtom.reportWrite(value, super.results, () {
      super.results = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_VideoSearchController.isLoading', context: context);

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
      Atom(name: '_VideoSearchController.errorMessage', context: context);

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

  late final _$searchAsyncAction =
      AsyncAction('_VideoSearchController.search', context: context);

  @override
  Future<void> search() {
    return _$searchAsyncAction.run(() => super.search());
  }

  late final _$applyFilterAsyncAction =
      AsyncAction('_VideoSearchController.applyFilter', context: context);

  @override
  Future<void> applyFilter(SearchFilterOption option) {
    return _$applyFilterAsyncAction.run(() => super.applyFilter(option));
  }

  late final _$removeLastFilterAsyncAction =
      AsyncAction('_VideoSearchController.removeLastFilter', context: context);

  @override
  Future<void> removeLastFilter() {
    return _$removeLastFilterAsyncAction.run(() => super.removeLastFilter());
  }

  late final _$_VideoSearchControllerActionController =
      ActionController(name: '_VideoSearchController', context: context);

  @override
  void setQuery(String value) {
    final _$actionInfo = _$_VideoSearchControllerActionController.startAction(
        name: '_VideoSearchController.setQuery');
    try {
      return super.setQuery(value);
    } finally {
      _$_VideoSearchControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clear() {
    final _$actionInfo = _$_VideoSearchControllerActionController.startAction(
        name: '_VideoSearchController.clear');
    try {
      return super.clear();
    } finally {
      _$_VideoSearchControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
query: ${query},
submittedQuery: ${submittedQuery},
params: ${params},
applied: ${applied},
filters: ${filters},
results: ${results},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
hasActiveFilters: ${hasActiveFilters}
    ''';
  }
}
