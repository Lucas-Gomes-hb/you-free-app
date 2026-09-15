import 'package:dio/dio.dart';

/// Minimal InnerTube (YouTube's private API) client.
///
/// Each client identity unlocks a different response shape. We use:
///   * [web]       — search, channels, playlists (classic renderers + lockups)
///   * [androidVr] — the player endpoint; it is the one identity that still
///                   returns plain `url` fields instead of `signatureCipher`,
///                   so no JS challenge has to be solved on-device.
///   * [android]   — playlist fallback, which returns `playlistVideoRenderer`
///                   instead of the newer lockup view models.
class InnertubeClient {
  static const _defaultHost = 'www.youtube.com';

  static const _webUa =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';
  static const _androidVrUa =
      'com.google.android.apps.youtube.vr.oculus/1.62.27 (Linux; U; Android 12)';
  static const _androidUa = 'com.google.android.youtube/20.10.38 (Linux; U; Android 12)';
  static const _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X)';

  /// YouTube Music. The only identity whose streams the CDN still serves in
  /// full, and the reason [YoutubeJsEngine] exists: it hands back ciphered
  /// signatures and demands a proof-of-origin token on the stream URL.
  static const webRemix = InnertubeIdentity(
    name: 'WEB_REMIX',
    version: '1.20260908.14.00',
    userAgent: _webUa,
    id: 67,
    host: 'music.youtube.com',
    context: {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20260908.14.00',
    },
  );

  static const web = InnertubeIdentity(
    name: 'WEB',
    version: '2.20250101.00.00',
    userAgent: _webUa,
    id: 1,
    context: {'clientName': 'WEB', 'clientVersion': '2.20250101.00.00'},
  );

  static const androidVr = InnertubeIdentity(
    name: 'ANDROID_VR',
    version: '1.62.27',
    userAgent: _androidVrUa,
    id: 28,
    context: {
      'clientName': 'ANDROID_VR',
      'clientVersion': '1.62.27',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': 32,
      'osName': 'Android',
      'osVersion': '12',
    },
  );

  /// Second choice for the player: it answers for videos where ANDROID_VR is
  /// met with a bot check, but it never carries muxed (video+audio) formats.
  static const ios = InnertubeIdentity(
    name: 'IOS',
    version: '20.10.4',
    userAgent: _iosUa,
    id: 5,
    context: {
      'clientName': 'IOS',
      'clientVersion': '20.10.4',
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
      'osName': 'iPhone',
      'osVersion': '18.3.2.22D82',
    },
  );

  static const android = InnertubeIdentity(
    name: 'ANDROID',
    version: '20.10.38',
    userAgent: _androidUa,
    id: 3,
    context: {
      'clientName': 'ANDROID',
      'clientVersion': '20.10.38',
      'androidSdkVersion': 32,
      'osName': 'Android',
      'osVersion': '12',
    },
  );

  final Dio _dio;
  final String hl;
  final String gl;

  /// Anonymous session id. Without it YouTube answers `LOGIN_REQUIRED`
  /// ("confirm you are not a bot") for a large share of videos.
  String? _visitorData;
  Future<String?>? _visitorRequest;

  InnertubeClient({String? hl, String? gl})
      : hl = hl ?? 'pt',
        gl = gl ?? 'BR',
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.json,
        ));

  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> body, {
    InnertubeIdentity client = web,
  }) async {
    final visitorData = await _visitor();

    final payload = <String, dynamic>{
      'context': {
        'client': {
          ...client.context,
          'hl': hl,
          'gl': gl,
          if (visitorData != null) 'visitorData': visitorData,
        },
      },
      ...body,
    };

    final response = await _dio.post<dynamic>(
      'https://${client.host}/youtubei/v1/$endpoint',
      queryParameters: const {'prettyPrint': 'false'},
      data: payload,
      options: Options(headers: {
        'Content-Type': 'application/json',
        'User-Agent': client.userAgent,
        'X-YouTube-Client-Name': '${client.id}',
        'X-YouTube-Client-Version': client.version,
        'Origin': 'https://${client.host}',
        if (visitorData != null) 'X-Goog-Visitor-Id': visitorData,
      }),
    );

    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// Drops the cached session id so the next call negotiates a fresh one.
  void resetVisitor() {
    _visitorData = null;
    _visitorRequest = null;
  }

  /// Fetched once per session, and shared by concurrent callers.
  Future<String?> _visitor() {
    final cached = _visitorData;
    if (cached != null) return Future.value(cached);
    return _visitorRequest ??= _fetchVisitor();
  }

  Future<String?> _fetchVisitor() async {
    try {
      final response = await _dio.post<dynamic>(
        'https://$_defaultHost/youtubei/v1/visitor_id',
        queryParameters: const {'prettyPrint': 'false'},
        data: {
          'context': {
            'client': {...web.context, 'hl': hl, 'gl': gl},
          }
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'User-Agent': web.userAgent,
        }),
      );
      final visitorData =
          response.data?['responseContext']?['visitorData'] as String?;
      _visitorData = visitorData;
      return visitorData;
    } catch (_) {
      // Requests still work for most videos without it.
      _visitorRequest = null;
      return null;
    }
  }

  void close() => _dio.close(force: true);
}

class InnertubeIdentity {
  final String name;
  final String version;
  final String userAgent;
  final int id;
  final Map<String, dynamic> context;

  /// InnerTube host this identity talks to; YouTube Music has its own.
  final String host;

  const InnertubeIdentity({
    required this.name,
    required this.version,
    required this.userAgent,
    required this.id,
    required this.context,
    this.host = InnertubeClient._defaultHost,
  });
}
