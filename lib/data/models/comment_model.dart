/// A single top-level comment on the watch page.
class VideoComment {
  final String id;
  final String authorId;
  final String? authorName;
  final String? authorThumbnail;
  final String text;
  final int likeCount;
  final String? publishedText;
  final int replyCount;

  /// The video's own author left a heart on this comment, which YouTube marks
  /// with a distinctive badge and the community reads as a pinned signal.
  final bool isCreatorHearted;

  final bool isPinned;

  VideoComment({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorThumbnail,
    required this.text,
    this.likeCount = 0,
    this.publishedText,
    this.replyCount = 0,
    this.isCreatorHearted = false,
    this.isPinned = false,
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    return VideoComment(
      id: json['id'] ?? '',
      authorId: json['author_id'] ?? json['authorId'] ?? '',
      authorName: json['author_name'] ?? json['authorName'],
      authorThumbnail: json['author_thumbnail'] ?? json['authorThumbnail'],
      text: json['text'] ?? '',
      likeCount: (json['like_count'] as num?)?.toInt() ??
          (json['likeCount'] as num?)?.toInt() ??
          0,
      publishedText: json['published_text'] ?? json['publishedText'],
      replyCount: (json['reply_count'] as num?)?.toInt() ??
          (json['replyCount'] as num?)?.toInt() ??
          0,
      isCreatorHearted: json['is_creator_hearted'] == true ||
          json['isCreatorHearted'] == true,
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
    );
  }
}

/// A page of comments plus the token that fetches the next one.
class CommentPage {
  final List<VideoComment> comments;
  final String? continuation;

  const CommentPage({required this.comments, this.continuation});

  factory CommentPage.fromJson(Map<String, dynamic> json) {
    return CommentPage(
      comments: (json['comments'] as List?)
              ?.map((e) => VideoComment.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      continuation: json['continuation'] as String?,
    );
  }
}
