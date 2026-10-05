import 'package:mobx/mobx.dart';

import '../../data/models/comment_model.dart';
import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';

part 'video_watch_controller.g.dart';

/// Everything the watch page shows for one video: the header, the "up next"
/// rail and the comment thread.
///
/// The three load independently so a slow comment section never holds back the
/// player controls, and each keeps its own error so one failing section can be
/// retried on its own.
class VideoWatchController = _VideoWatchController
    with _$VideoWatchController;

abstract class _VideoWatchController with Store {
  final ContentSource _source;
  final String videoId;

  _VideoWatchController(this._source, this.videoId);

  @observable
  VideoDetails? details;

  @observable
  bool isLoadingDetails = false;

  @observable
  String? detailsError;

  @observable
  ObservableList<VideoModel> related = ObservableList<VideoModel>();

  @observable
  bool isLoadingRelated = false;

  @observable
  String? relatedError;

  @observable
  ObservableList<VideoComment> comments = ObservableList<VideoComment>();

  @observable
  bool isLoadingComments = false;

  @observable
  bool isLoadingMoreComments = false;

  @observable
  String? commentsError;

  @observable
  CommentSort commentSort = CommentSort.top;

  String? _continuation;

  bool get hasMoreComments => _continuation != null;

  @action
  Future<void> load() async {
    await Future.wait([loadDetails(), loadRelated(), loadComments()]);
  }

  @action
  Future<void> loadDetails() async {
    isLoadingDetails = true;
    detailsError = null;
    try {
      details = await _source.getVideoDetails(videoId);
    } catch (e) {
      detailsError = 'Não foi possível carregar os detalhes';
    } finally {
      isLoadingDetails = false;
    }
  }

  @action
  Future<void> loadRelated() async {
    isLoadingRelated = true;
    relatedError = null;
    try {
      related = ObservableList.of(await _source.getRelated(videoId));
    } catch (e) {
      relatedError = 'Não foi possível carregar os próximos vídeos';
    } finally {
      isLoadingRelated = false;
    }
  }

  @action
  Future<void> loadComments() async {
    isLoadingComments = true;
    commentsError = null;
    _continuation = null;
    comments.clear();
    try {
      final page = await _source.getComments(
        videoId,
        sort: commentSort,
      );
      comments = ObservableList.of(page.comments);
      _continuation = page.continuation;
    } catch (e) {
      commentsError = 'Não foi possível carregar os comentários';
    } finally {
      isLoadingComments = false;
    }
  }

  /// Switches the ordering and reloads from scratch: a continuation token is
  /// bound to the ordering it was issued for, so paging into the old one would
  /// splice two different orderings together.
  @action
  Future<void> setCommentSort(CommentSort sort) async {
    if (sort == commentSort) return;
    commentSort = sort;
    await loadComments();
  }

  @action
  Future<void> loadMoreComments() async {
    if (_continuation == null || isLoadingMoreComments) return;
    isLoadingMoreComments = true;
    try {
      final page = await _source.getComments(
        videoId,
        continuation: _continuation,
        sort: commentSort,
      );
      final known = comments.map((c) => c.id).toSet();
      comments.addAll(page.comments.where((c) => !known.contains(c.id)));
      _continuation = page.continuation;
    } catch (e) {
      commentsError = 'Não foi possível carregar mais comentários';
    } finally {
      isLoadingMoreComments = false;
    }
  }
}
