// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_home_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoHomeController on _VideoHomeController, Store {
  late final _$feedAtom =
      Atom(name: '_VideoHomeController.feed', context: context);

  @override
  ObservableList<VideoModel> get feed {
    _$feedAtom.reportRead();
    return super.feed;
  }

  @override
  set feed(ObservableList<VideoModel> value) {
    _$feedAtom.reportWrite(value, super.feed, () {
      super.feed = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_VideoHomeController.isLoading', context: context);

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

  late final _$isLoadingMoreAtom =
      Atom(name: '_VideoHomeController.isLoadingMore', context: context);

  @override
  bool get isLoadingMore {
    _$isLoadingMoreAtom.reportRead();
    return super.isLoadingMore;
  }

  @override
  set isLoadingMore(bool value) {
    _$isLoadingMoreAtom.reportWrite(value, super.isLoadingMore, () {
      super.isLoadingMore = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_VideoHomeController.errorMessage', context: context);

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

  late final _$loadAsyncAction =
      AsyncAction('_VideoHomeController.load', context: context);

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$loadMoreAsyncAction =
      AsyncAction('_VideoHomeController.loadMore', context: context);

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  @override
  String toString() {
    return '''
feed: ${feed},
isLoading: ${isLoading},
isLoadingMore: ${isLoadingMore},
errorMessage: ${errorMessage}
    ''';
  }
}
