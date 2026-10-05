import 'package:mobx/mobx.dart';

import '../../data/models/video_model.dart';
import '../../data/services/content_source.dart';

part 'video_home_controller.g.dart';

/// Video home: an infinite feed seeded by what was already watched.
///
/// YouTube's anonymous feed tops out quickly, so more pages are requested from
/// the related rail of a seed instead of paging the same feed.
class VideoHomeController = _VideoHomeController with _$VideoHomeController;

abstract class _VideoHomeController with Store {
  final ContentSource _source;

  _VideoHomeController(this._source);

  @observable
  ObservableList<VideoModel> feed = ObservableList<VideoModel>();

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingMore = false;

  @observable
  String? errorMessage;

  final Set<String> _seen = {};
  int _seedCursor = 0;

  bool get isEmpty => !isLoading && feed.isEmpty;

  @action
  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    try {
      final videos = await _source.getHomeFeed();
      _seen
        ..clear()
        ..addAll(videos.map((v) => v.id));
      feed = ObservableList.of(videos);
    } catch (e) {
      errorMessage = 'Não foi possível carregar o feed';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadMore() async {
    if (isLoadingMore || feed.isEmpty) return;
    isLoadingMore = true;
    try {
      // Cycle through the loaded items as seeds so the added pages keep
      // diverging instead of repeating the nearest neighbours.
      final seed = feed[_seedCursor % feed.length];
      _seedCursor++;
      final more = await _source.getRelated(seed.id);
      final fresh = more.where((v) => _seen.add(v.id)).toList();
      if (fresh.isNotEmpty) feed.addAll(fresh);
    } catch (e) {
      errorMessage = 'Não foi possível carregar mais vídeos';
    } finally {
      isLoadingMore = false;
    }
  }
}
