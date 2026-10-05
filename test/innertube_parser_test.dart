import 'package:flutter_test/flutter_test.dart';
import 'package:youfree/data/models/video_model.dart';
import 'package:youfree/data/services/youtube/innertube_parser.dart';

void main() {
  group('view count parsing', () {
    test('parses pt-BR abbreviations', () {
      expect(VideoModel.parseViewCount('1,2 mi de visualizações'), 1200000);
      expect(VideoModel.parseViewCount('345 mil visualizações'), 345000);
      expect(VideoModel.parseViewCount('12 visualizações'), 12);
    });

    test('parses en abbreviations', () {
      expect(VideoModel.parseViewCount('1.2M views'), 1200000);
      expect(VideoModel.parseViewCount('13,5 mil views'), 13500);
      expect(VideoModel.parseViewCount('3B views'), 3000000000);
    });

    test('returns null when there is no number', () {
      expect(VideoModel.parseViewCount(null), isNull);
      expect(VideoModel.parseViewCount('sem números'), isNull);
    });

    test('formats counts back for display', () {
      expect(VideoModel.formatViewCount(1200000), '1,2 mi');
      expect(VideoModel.formatViewCount(345000), '345 mil');
      expect(VideoModel.formatViewCount(42), '42');
      expect(VideoModel.formatViewCount(null), '');
    });
  });

  group('grid video metadata', () {
    test('reads views, date, channel and badges from a videoRenderer', () {
      final renderer = {
        'videoId': 'dQw4w9WgXcQ',
        'title': {
          'runs': [
            {'text': 'Nunca Gonna Give You Up'}
          ]
        },
        'thumbnail': {
          'thumbnails': [
            {
              'url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
              'width': 480
            },
          ],
        },
        'lengthText': {'simpleText': '3:33'},
        'ownerText': {
          'runs': [
            {'text': 'Rick Astley'}
          ]
        },
        'shortViewCountText': {
          'runs': [
            {'text': '1,4 bi de visualizações'}
          ]
        },
        'publishedTimeText': {'simpleText': 'há 16 anos'},
        'channelThumbnailSupportedRenderers': {
          'thumbnail': {
            'thumbnails': [
              {'url': 'https://yt3.ggpht.com/chan.jpg', 'width': 176},
            ],
          },
        },
        'thumbnailOverlayTimeStatusRenderer': {
          'text': {'simpleText': 'AO VIVO'},
          'style': 'BADGE_STYLE_TYPE_LIVE_NOW',
        },
      };

      final video = InnertubeParser.videoFromRenderer(renderer)!;
      expect(video.id, 'dQw4w9WgXcQ');
      expect(video.viewCount, 1400000000);
      expect(video.publishedText, 'há 16 anos');
      expect(video.isLive, isTrue);
      expect(
        video.channelThumbnail,
        'https://yt3.ggpht.com/chan.jpg',
      );
      expect(video.durationFormatted, '3:33');
    });

    test('meta line joins only the parts that are known', () {
      final video = VideoModel(
        id: 'aaaaaaaaaaa',
        title: 'T',
        url: 'u',
        uploader: 'Canal',
        viewCount: 1500,
        publishedText: 'há 2 dias',
      );
      expect(video.metaLine, 'Canal · 2 mil visualizações · há 2 dias');

      final sparse = VideoModel(id: 'aaaaaaaaaaa', title: 'T', url: 'u');
      expect(sparse.metaLine, '');
    });
  });

  group('watch page details', () {
    test('reads title, description, channel, views and likes', () {
      final payload = {
        'videoDetails': {
          'videoId': 'dQw4w9WgXcQ',
          'title': 'Nunca Gonna Give You Up',
          'lengthSeconds': '212',
          'viewCount': '1400000000',
        },
        'videoPrimaryInfoRenderer': {
          'title': {
            'runs': [
              {'text': 'Nunca Gonna Give You Up'}
            ]
          },
          'viewCount': {
            'videoViewCountRenderer': {
              'viewCount': {
                'simpleText': '1.4 billion views',
                'viewCount': '1400000000',
              },
            }
          },
          'dateText': {'simpleText': 'Oct 25, 2009'},
          // The action row: the like button is first and its label is the
          // bare count, with no visible text.
          'videoActions': {
            'menuRenderer': {
              'topLevelButtons': [
                {
                  'toggleButtonRenderer': {
                    'defaultText': {
                      'accessibility': {
                        'accessibilityData': {'label': '2,8 mi'},
                      },
                    },
                  },
                },
                {
                  'toggleButtonRenderer': {
                    'defaultText': {
                      'accessibility': {'label': 'Não curtir'},
                    },
                  },
                },
              ],
            },
          },
        },
        'videoSecondaryInfoRenderer': {
          'owner': {
            'videoOwnerRenderer': {
              'title': {
                'runs': [
                  {'text': 'Rick Astley'}
                ]
              },
              'subscriberCountText': {'simpleText': '4,6 mi de inscritos'},
              'navigationEndpoint': {
                'browseEndpoint': {
                  'browseId': 'UCuAXFkgsw1L7xaCfnd5JJOw',
                  'canonicalBaseUrl': '/@RickAstleyYT',
                },
              },
              'thumbnails': [
                {'url': 'https://yt3.ggpht.com/rick.jpg', 'width': 176},
              ],
            },
          },
          'description': {
            'runs': [
              {'text': 'The official video'}
            ]
          },
        },
      };

      final details = InnertubeParser.videoDetailsFrom(payload, 'dQw4w9WgXcQ')!;
      expect(details.title, 'Nunca Gonna Give You Up');
      expect(details.description, 'The official video');
      expect(details.channelName, 'Rick Astley');
      expect(details.channelUrl, 'https://www.youtube.com/@RickAstleyYT');
      expect(details.channelThumbnail, 'https://yt3.ggpht.com/rick.jpg');
      expect(details.duration, 212);
      expect(details.viewCount, 1400000000);
      expect(details.likeCount, 2800000);
      expect(details.publishedText, 'Oct 25, 2009');
    });

    test('rejects a malformed video id', () {
      expect(InnertubeParser.videoDetailsFrom(const {}, 'curto'), isNull);
    });

    test('merges a feed card under the full metadata', () {
      final seed = VideoModel(
        id: 'dQw4w9WgXcQ',
        title: 'Título antigo',
        url: 'u',
        thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        uploader: 'Rick Astley',
        viewCount: 100,
      );
      final details = VideoDetails(
        id: 'dQw4w9WgXcQ',
        title: 'Título correto',
        viewCount: 999,
      ).merge(seed);

      expect(details.title, 'Título correto');
      expect(details.viewCount, 999);
      // Falls back to what the card already knew.
      expect(details.channelName, 'Rick Astley');
      expect(details.thumbnail, contains('hqdefault'));
    });
  });

  group('comments', () {
    test('parses a thread and counts its replies', () {
      final payload = {
        'contents': {
          'commentThreadRenderer': {
            'comments': {
              'commentRenderer': {
                'commentId': 'c1',
                'authorId': 'UC123',
                'authorText': {'simpleText': 'Ana'},
                'contentText': {
                  'runs': [
                    {'text': 'Melhor  vídeo!'}
                  ]
                },
                'publishedTimeText': {'simpleText': 'há 2 dias'},
                'voteCount': {'simpleText': '1,2 mil'},
                'authorThumbnail': {
                  'thumbnails': [
                    {'url': 'https://yt3.ggpht.com/ana.jpg', 'width': 64},
                  ],
                },
              },
            },
            'commentRepliesRenderer': {
              'contents': {
                'commentThreadRenderer': {
                  'comments': {
                    'commentRenderer': {
                      'commentId': 'c2',
                      'contentText': {
                        'runs': [
                          {'text': 'Concordo'}
                        ]
                      },
                    },
                  },
                },
              },
            },
          },
        },
      };

      final page = InnertubeParser.commentsFrom(payload);
      expect(page.comments, hasLength(1));
      final comment = page.comments.first;
      expect(comment.id, 'c1');
      expect(comment.authorName, 'Ana');
      expect(comment.text, 'Melhor vídeo!');
      expect(comment.likeCount, 1200);
      expect(comment.replyCount, 1);
      expect(comment.authorThumbnail, 'https://yt3.ggpht.com/ana.jpg');
    });

    test(
        'does not duplicate a comment that appears as both thread and renderer',
        () {
      final renderer = {
        'commentId': 'c9',
        'authorId': 'UC9',
        'contentText': {
          'runs': [
            {'text': 'Repetido'}
          ]
        },
      };
      final payload = {
        'commentThreadRenderer': {
          'comments': {'commentRenderer': renderer},
        },
        'commentRenderer': renderer,
      };

      expect(InnertubeParser.commentsFrom(payload).comments, hasLength(1));
    });

    test('"Recentes" boots the section with the token of the sort menu', () {
      // Ordering is not a request parameter. Each option in the comment
      // section's sort menu carries its own continuation, so asking for the
      // newest comments means booting the section with the other token. Reading
      // the pinned one instead would silently return the top comments again,
      // which is exactly the bug the option was supposed to fix.
      final payload = {
        'engagementPanels': [
          {
            'engagementPanelSectionListRenderer': {
              'header': {
                'engagementPanelTitleHeaderRenderer': {
                  'menu': {
                    'sortFilterSubMenuRenderer': {
                      'subMenuItems': [
                        {
                          'title': 'Principais',
                          'selected': true,
                          'serviceEndpoint': {
                            'continuationCommand': {'token': 'TOKEN_TOP'},
                          },
                        },
                        {
                          'title': 'Mais recentes',
                          'serviceEndpoint': {
                            'continuationCommand': {'token': 'TOKEN_NEW'},
                          },
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
        ],
      };
      expect(InnertubeParser.commentSortToken(payload, 'newest'),
          'TOKEN_NEW');
      // Any other ordering keeps the default token, not one of the menu's.
      expect(InnertubeParser.commentSortToken(payload, 'top'), isNull);
    });

    test('skips renderers with no text', () {
      final payload = {
        'commentRenderer': {
          'commentId': 'c0',
          'contentText': {'runs': []}
        },
      };
      expect(InnertubeParser.commentsFrom(payload).comments, isEmpty);
    });

    test('keeps a synthetic id when YouTube omits commentId', () {
      final payload = {
        'commentRenderer': {
          'authorId': 'UC7',
          'contentText': {
            'runs': [
              {'text': 'sem id'}
            ]
          },
        },
      };
      final comment = InnertubeParser.commentsFrom(payload).comments.first;
      expect(comment.id, startsWith('cmt_'));
      expect(comment.text, 'sem id');
    });

    test('reads the continuation token for paging', () {
      final payload = {
        'continuationContents': {
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'TOKEN123'},
            },
          },
        },
      };
      expect(InnertubeParser.commentsFrom(payload).continuation, 'TOKEN123');
    });

    test('flags the creator heart', () {
      final payload = {
        'commentRenderer': {
          'commentId': 'c3',
          'contentText': {
            'runs': [
              {'text': 'do criador'}
            ]
          },
          'creatorHeart': {},
        },
      };
      expect(
        InnertubeParser.commentsFrom(payload).comments.first.isCreatorHearted,
        isTrue,
      );
    });
  });

  group('current innerTube payload shapes', () {
    // Captured verbatim from YouTube. The watch page nests the view count one
    // level below where the field name suggests, and the like button is a stack
    // of self-nesting view models keyed by iconName.
    final Map<String, dynamic> watchNext = {
      'contents': {
        'twoColumnWatchNextResults': {
          'results': {
            'results': {
              'contents': [
                {
                  'videoPrimaryInfoRenderer': {
                    'title': {'simpleText': 'Never Gonna Give You Up'},
                    'dateText': {'simpleText': '24 de out. de 2009'},
                    'viewCount': {
                      'videoViewCountRenderer': {
                        'viewCount': {
                          'simpleText': '1.820.942.046 visualizações'
                        },
                        'originalViewCount': '0',
                      },
                    },
                    'videoActions': {
                      'menuRenderer': {
                        'topLevelButtons': [
                          {
                            'segmentedLikeDislikeButtonViewModel': {
                              'likeButtonViewModel': {
                                'likeButtonViewModel': {
                                  'toggleButtonViewModel': {
                                    'toggleButtonViewModel': {
                                      'defaultButtonViewModel': {
                                        'buttonViewModel': {
                                          'iconName': 'LIKE',
                                          'title': '19 mi',
                                        },
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        ],
                      },
                    },
                  },
                },
              ],
            },
          },
          'secondaryResults': {
            'secondaryResults': {
              'results': [
                {
                  'videoSecondaryInfoRenderer': {
                    'attributedDescription': {
                      'content': 'A descrição oficial.'
                    },
                    'owner': {
                      'videoOwnerRenderer': {
                        'title': {'simpleText': 'Rick Astley'},
                        'subscriberCountText': {
                          'runs': [
                            {'text': '4,55 mi de inscritos'}
                          ]
                        },
                        'navigationEndpoint': {
                          'browseEndpoint': {
                            'canonicalBaseUrl': '/@RickAstleyYT'
                          },
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
        },
      },
    };

    test('reads the view count from the nested view count renderer', () {
      final details =
          InnertubeParser.videoDetailsFrom(watchNext, 'dQw4w9WgXcQ')!;
      expect(details.viewCount, 1820942046);
    });

    test('reads the like count from the like button view model', () {
      final details =
          InnertubeParser.videoDetailsFrom(watchNext, 'dQw4w9WgXcQ')!;
      expect(details.likeCount, 19000000);
    });

    test('falls back to the attributed description', () {
      final details =
          InnertubeParser.videoDetailsFrom(watchNext, 'dQw4w9WgXcQ')!;
      expect(details.description, 'A descrição oficial.');
      expect(details.channelName, 'Rick Astley');
      expect(details.channelUrl, 'https://www.youtube.com/@RickAstleyYT');
      expect(details.publishedText, '24 de out. de 2009');
    });

    test('takes the exact duration from the player half of the bundle', () {
      // `next` alone carries no duration at all, so the two endpoints are merged
      // into one bundle by the caller.
      final details = InnertubeParser.videoDetailsFrom({
        'next': watchNext,
        'player': {
          'videoDetails': {
            'title': 'Never Gonna Give You Up',
            'lengthSeconds': '213',
            'viewCount': '1820942046',
            'shortDescription': 'do player',
          },
        },
      }, 'dQw4w9WgXcQ')!;
      expect(details.duration, 213);
      expect(details.viewCount, 1820942046);
    });

    test('strips the invisible bidi marks youtube leaves in labels', () {
      final details = InnertubeParser.videoDetailsFrom({
        'videoPrimaryInfoRenderer': {
          'title': {'simpleText': 'Alta\u200eDefini\u200fção\u200e'},
        },
      }, 'dQw4w9WgXcQ')!;
      expect(details.title, 'AltaDefinição');
    });

    group('lockup lists', () {
      // The newer list item. The duration hides in a thumbnail badge and the
      // counts arrive as one flat run of text parts with no word to match on.
      final lockup = {
        'contentId': '1n5pMgUPYnk',
        'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
        'contentImage': {
          'thumbnailViewModel': {
            'image': {
              'sources': [
                {
                  'url': 'https://i.ytimg.com/vi/1n5pMgUPYnk/hq.jpg',
                  'width': 336,
                  'height': 188
                },
              ],
            },
          },
          'overlays': [
            {
              'thumbnailBottomOverlayViewModel': {
                'badges': [
                  {
                    'thumbnailBadgeViewModel': {
                      'icon': {
                        'sources': [
                          {
                            'clientResource': {'imageName': 'MUSIC'}
                          }
                        ]
                      },
                      'text': '1:57:09',
                    },
                  },
                ],
              },
            },
          ],
        },
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Vintage Vibes: Best of 80s'},
            'metadata': {
              'contentMetadataViewModel': {
                'metadataRows': [
                  {
                    'metadataParts': [
                      {
                        'text': {'content': 'R&B Afterglow'}
                      },
                    ],
                  },
                  {
                    'metadataParts': [
                      {
                        'text': {'content': '3,1 mi'},
                        'accessibilityLabel': '3,1 milhão de visualizações'
                      },
                      {
                        'text': {'content': 'há 2 meses'}
                      },
                    ],
                  },
                ],
              },
            },
          },
        },
      };

      test('reads the byline, views and age positionally', () {
        // YouTube keys each list entry, so the item arrives wrapped.
        final video = InnertubeParser.videosFrom({
          'contents': [
            {'lockupViewModel': lockup}
          ]
        }).single;
        expect(video.title, 'Vintage Vibes: Best of 80s');
        expect(video.uploader, 'R&B Afterglow');
        expect(video.viewCount, 3100000);
        expect(video.publishedText, 'há 2 meses');
      });

      test('reads the duration from the badge without it polluting views', () {
        // YouTube keys each list entry, so the item arrives wrapped.
        final video = InnertubeParser.videosFrom({
          'contents': [
            {'lockupViewModel': lockup}
          ]
        }).single;
        expect(video.duration, 7029);
        expect(video.viewCount, 3100000);
      });

      test('keeps document order when renderers and lockups are mixed', () {
        final list = [
          {
            'videoRenderer': {
              'videoId': 'aaaaaaaaaaa',
              'title': {'simpleText': 'antigo'},
              'lengthText': {'simpleText': '3:00'},
            },
          },
          {'lockupViewModel': lockup},
          {
            'videoRenderer': {
              'videoId': 'bbbbbbbbbbb',
              'title': {'simpleText': 'antigo 2'},
              'lengthText': {'simpleText': '4:00'},
            },
          },
        ];
        final videos = InnertubeParser.videosFrom({'contents': list});
        expect(videos.map((v) => v.id).toList(),
            ['aaaaaaaaaaa', '1n5pMgUPYnk', 'bbbbbbbbbbb']);
      });
    });

    group('comment entities', () {
      // Comment paging moved to a flat entity batch; the ordered
      // `continuationItems` only carry references, and they are what hold the
      // ranking and the pinned flag.
      final Map<String, dynamic> commentEntities = {
        'onResponseReceivedEndpoints': [
          {
            'reloadContinuationItemsCommand': {
              'continuationItems': [
                {
                  'commentThreadRenderer': {
                    'renderingPriority': 'RENDERING_PRIORITY_PINNED_COMMENT',
                    'commentViewModel': {
                      'commentViewModel': {
                        'commentKey': 'K1',
                        'commentId': 'c1',
                        'toolbarStateKey': 'T1',
                        'pinnedText': 'Fixado por @RickAstleyYT',
                      },
                    },
                  },
                },
                {
                  'commentThreadRenderer': {
                    'commentViewModel': {
                      'commentViewModel': {
                        'commentKey': 'K2',
                        'commentId': 'c2',
                        'toolbarStateKey': 'T2',
                      },
                    },
                  },
                },
              ],
            },
          },
        ],
        'frameworkUpdates': {
          'entityBatchUpdate': {
            'mutations': [
              {
                'payload': {
                  'commentEntityPayload': {
                    'key': 'K1',
                    'properties': {
                      'commentId': 'c1',
                      'content': {
                        'content': 'can confirm: he never gave us up'
                      },
                      'publishedTime': 'há 1 ano',
                      'replyLevel': 0,
                    },
                    'author': {
                      'channelId': 'UCBR8',
                      'displayName': '@YouTube',
                    },
                    'toolbar': {
                      'likeCountNotliked': '321 mil',
                      'replyCount': '963',
                    },
                  },
                },
              },
              {
                'payload': {
                  'engagementToolbarStateEntityPayload': {
                    'key': 'T1',
                    'heartState': 'TOOLBAR_HEART_STATE_HEARTED',
                  },
                },
              },
              {
                'payload': {
                  'engagementToolbarStateEntityPayload': {
                    'key': 'T2',
                    'heartState': 'TOOLBAR_HEART_STATE_UNHEARTED',
                  },
                },
              },
              {
                'payload': {
                  'commentEntityPayload': {
                    'key': 'K2',
                    'properties': {
                      'commentId': 'c2',
                      'content': {'content': 'eu sabia que era pegadinha'},
                      'publishedTime': 'há 6 anos',
                      'replyLevel': 0,
                    },
                    'author': {
                      'channelId': 'UCXX',
                      'displayName': '@grustache4569',
                    },
                    'toolbar': {
                      'likeCountNotliked': '102 mil',
                      'replyCount': '561'
                    },
                  },
                },
              },
            ],
          },
        },
      };

      test('reads bodies, counts and author names', () {
        final comments = InnertubeParser.commentsFrom(commentEntities).comments;
        expect(comments, hasLength(2));
        expect(comments.first.text, 'can confirm: he never gave us up');
        expect(comments.first.likeCount, 321000);
        expect(comments.first.replyCount, 963);
        expect(comments.first.publishedText, 'há 1 ano');
        expect(comments.first.authorName, 'YouTube');
      });

      test('keeps the ranking order of the continuation items', () {
        final comments = InnertubeParser.commentsFrom(commentEntities).comments;
        expect(comments.map((c) => c.id).toList(), ['c1', 'c2']);
      });

      test('reads the pinned flag and the creator heart', () {
        final comments = InnertubeParser.commentsFrom(commentEntities).comments;
        expect(comments.first.isPinned, isTrue);
        expect(comments.first.isCreatorHearted, isTrue);
        expect(comments.last.isPinned, isFalse);
        // `UNHEARTED` contains "HEARTED" but is the opposite meaning.
        expect(comments.last.isCreatorHearted, isFalse);
      });
    });
  });
}
