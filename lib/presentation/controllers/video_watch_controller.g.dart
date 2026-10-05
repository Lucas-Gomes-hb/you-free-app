// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_watch_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoWatchController on _VideoWatchController, Store {
  late final _$detailsAtom =
      Atom(name: '_VideoWatchController.details', context: context);

  @override
  VideoDetails? get details {
    _$detailsAtom.reportRead();
    return super.details;
  }

  @override
  set details(VideoDetails? value) {
    _$detailsAtom.reportWrite(value, super.details, () {
      super.details = value;
    });
  }

  late final _$isLoadingDetailsAtom =
      Atom(name: '_VideoWatchController.isLoadingDetails', context: context);

  @override
  bool get isLoadingDetails {
    _$isLoadingDetailsAtom.reportRead();
    return super.isLoadingDetails;
  }

  @override
  set isLoadingDetails(bool value) {
    _$isLoadingDetailsAtom.reportWrite(value, super.isLoadingDetails, () {
      super.isLoadingDetails = value;
    });
  }

  late final _$detailsErrorAtom =
      Atom(name: '_VideoWatchController.detailsError', context: context);

  @override
  String? get detailsError {
    _$detailsErrorAtom.reportRead();
    return super.detailsError;
  }

  @override
  set detailsError(String? value) {
    _$detailsErrorAtom.reportWrite(value, super.detailsError, () {
      super.detailsError = value;
    });
  }

  late final _$relatedAtom =
      Atom(name: '_VideoWatchController.related', context: context);

  @override
  ObservableList<VideoModel> get related {
    _$relatedAtom.reportRead();
    return super.related;
  }

  @override
  set related(ObservableList<VideoModel> value) {
    _$relatedAtom.reportWrite(value, super.related, () {
      super.related = value;
    });
  }

  late final _$isLoadingRelatedAtom =
      Atom(name: '_VideoWatchController.isLoadingRelated', context: context);

  @override
  bool get isLoadingRelated {
    _$isLoadingRelatedAtom.reportRead();
    return super.isLoadingRelated;
  }

  @override
  set isLoadingRelated(bool value) {
    _$isLoadingRelatedAtom.reportWrite(value, super.isLoadingRelated, () {
      super.isLoadingRelated = value;
    });
  }

  late final _$relatedErrorAtom =
      Atom(name: '_VideoWatchController.relatedError', context: context);

  @override
  String? get relatedError {
    _$relatedErrorAtom.reportRead();
    return super.relatedError;
  }

  @override
  set relatedError(String? value) {
    _$relatedErrorAtom.reportWrite(value, super.relatedError, () {
      super.relatedError = value;
    });
  }

  late final _$commentsAtom =
      Atom(name: '_VideoWatchController.comments', context: context);

  @override
  ObservableList<VideoComment> get comments {
    _$commentsAtom.reportRead();
    return super.comments;
  }

  @override
  set comments(ObservableList<VideoComment> value) {
    _$commentsAtom.reportWrite(value, super.comments, () {
      super.comments = value;
    });
  }

  late final _$isLoadingCommentsAtom =
      Atom(name: '_VideoWatchController.isLoadingComments', context: context);

  @override
  bool get isLoadingComments {
    _$isLoadingCommentsAtom.reportRead();
    return super.isLoadingComments;
  }

  @override
  set isLoadingComments(bool value) {
    _$isLoadingCommentsAtom.reportWrite(value, super.isLoadingComments, () {
      super.isLoadingComments = value;
    });
  }

  late final _$isLoadingMoreCommentsAtom = Atom(
      name: '_VideoWatchController.isLoadingMoreComments', context: context);

  @override
  bool get isLoadingMoreComments {
    _$isLoadingMoreCommentsAtom.reportRead();
    return super.isLoadingMoreComments;
  }

  @override
  set isLoadingMoreComments(bool value) {
    _$isLoadingMoreCommentsAtom.reportWrite(value, super.isLoadingMoreComments,
        () {
      super.isLoadingMoreComments = value;
    });
  }

  late final _$commentsErrorAtom =
      Atom(name: '_VideoWatchController.commentsError', context: context);

  @override
  String? get commentsError {
    _$commentsErrorAtom.reportRead();
    return super.commentsError;
  }

  @override
  set commentsError(String? value) {
    _$commentsErrorAtom.reportWrite(value, super.commentsError, () {
      super.commentsError = value;
    });
  }

  late final _$commentSortAtom =
      Atom(name: '_VideoWatchController.commentSort', context: context);

  @override
  CommentSort get commentSort {
    _$commentSortAtom.reportRead();
    return super.commentSort;
  }

  @override
  set commentSort(CommentSort value) {
    _$commentSortAtom.reportWrite(value, super.commentSort, () {
      super.commentSort = value;
    });
  }

  late final _$loadAsyncAction =
      AsyncAction('_VideoWatchController.load', context: context);

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$loadDetailsAsyncAction =
      AsyncAction('_VideoWatchController.loadDetails', context: context);

  @override
  Future<void> loadDetails() {
    return _$loadDetailsAsyncAction.run(() => super.loadDetails());
  }

  late final _$loadRelatedAsyncAction =
      AsyncAction('_VideoWatchController.loadRelated', context: context);

  @override
  Future<void> loadRelated() {
    return _$loadRelatedAsyncAction.run(() => super.loadRelated());
  }

  late final _$loadCommentsAsyncAction =
      AsyncAction('_VideoWatchController.loadComments', context: context);

  @override
  Future<void> loadComments() {
    return _$loadCommentsAsyncAction.run(() => super.loadComments());
  }

  late final _$setCommentSortAsyncAction =
      AsyncAction('_VideoWatchController.setCommentSort', context: context);

  @override
  Future<void> setCommentSort(CommentSort sort) {
    return _$setCommentSortAsyncAction.run(() => super.setCommentSort(sort));
  }

  late final _$loadMoreCommentsAsyncAction =
      AsyncAction('_VideoWatchController.loadMoreComments', context: context);

  @override
  Future<void> loadMoreComments() {
    return _$loadMoreCommentsAsyncAction.run(() => super.loadMoreComments());
  }

  @override
  String toString() {
    return '''
details: ${details},
isLoadingDetails: ${isLoadingDetails},
detailsError: ${detailsError},
related: ${related},
isLoadingRelated: ${isLoadingRelated},
relatedError: ${relatedError},
comments: ${comments},
isLoadingComments: ${isLoadingComments},
isLoadingMoreComments: ${isLoadingMoreComments},
commentsError: ${commentsError},
commentSort: ${commentSort}
    ''';
  }
}
