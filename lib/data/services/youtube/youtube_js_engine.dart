import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'youtube_js_runtime.dart';

/// Runs the JavaScript YouTube requires, inside a headless WebView.
///
/// Two things cannot be done in Dart: descrambling the player signature and
/// the `n` parameter (both need YouTube's own player script), and minting a
/// proof-of-origin token (BotGuard probes real browser APIs). A WebView is a
/// real browser engine on both Android and iOS, so it handles both.
///
/// The page is parked on the https://www.youtube.com origin, which makes the
/// player script and the BotGuard endpoints same-origin. InnerTube calls stay
/// on the Dart side, where CORS does not apply.
class YoutubeJsEngine implements YoutubeJsRuntime {
  static const _origin = 'https://www.youtube.com';
  static const _bridgeUrl = '$_origin/youfree-bridge';
  static const _bridgeHtml = '<!doctype html><html><head>'
      '<meta charset="utf-8"><title>youfree</title></head><body></body></html>';
  static const _bootTimeout = Duration(seconds: 45);
  static const _callTimeout = Duration(seconds: 45);

  /// The page has a real YouTube origin but no network of its own, so every
  /// request the JavaScript needs is performed here and bridged back.
  final Dio _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 40),
    responseType: ResponseType.plain,
    validateStatus: (_) => true,
  ));

  HeadlessInAppWebView? _webView;
  InAppWebViewController? _controller;
  Future<void>? _booting;

  int? _signatureTimestamp;

  /// Timestamp of the player script currently loaded; required by the
  /// WEB_REMIX player request, which answers UNPLAYABLE without it.
  int? get signatureTimestamp => _signatureTimestamp;

  Future<void> _ensureReady() => _booting ??= _boot();

  Future<void> _boot() async {
    final scripts = await Future.wait([
      rootBundle.loadString('assets/pot/ejs_lib.min.js'),
      rootBundle.loadString('assets/pot/ejs_core.min.js'),
      rootBundle.loadString('assets/pot/bgutils.cjs.js'),
      rootBundle.loadString('assets/pot/mint.js'),
      rootBundle.loadString('assets/pot/bridge.js'),
    ]);

    final ready = Completer<void>();
    final webView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        // BotGuard inspects the environment; a stock desktop identity is the
        // one its challenges are written for.
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
        incognito: false,
        clearCache: false,
        // Lets the bridge page be served as if it came from YouTube itself.
        useShouldInterceptRequest: true,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      // Serving our own HTML under a real YouTube URL is what gives the page a
      // true youtube.com origin. `loadData` with a base URL does not: Android
      // hands such documents an opaque origin, and every fetch from them fails.
      shouldInterceptRequest: (_, request) async {
        if (request.url.toString() != _bridgeUrl) return null;
        return WebResourceResponse(
          contentType: 'text/html',
          contentEncoding: 'utf-8',
          data: Uint8List.fromList(utf8.encode(_bridgeHtml)),
        );
      },
      onConsoleMessage: (_, message) {
        // The JS side is where this can break in ways Dart never sees.
        if (message.messageLevel == ConsoleMessageLevel.ERROR) {
          // ignore: avoid_print
          print('YouFree JS: ${message.message}');
        }
      },
      onReceivedError: (_, __, error) {
        // ignore: avoid_print
        print('YouFree WebView: ${error.description}');
      },
      onLoadStop: (controller, _) async {
        if (ready.isCompleted) return;
        try {
          // The interceptor was only there to serve the bootstrap document.
          // Leaving it on routes every later request through Dart, and fetch()
          // fails outright.
          await controller.setSettings(
            settings: InAppWebViewSettings(useShouldInterceptRequest: false),
          );
          // The solver bundle exports `lib`; the core bundle reads meriyah and
          // astring off the global object and defines `jsc`.
          _registerFetchBridge(controller);
          await controller.evaluateJavascript(source: scripts[0]);
          await controller.evaluateJavascript(
            source: 'Object.assign(window, lib); window.lib = lib;',
          );
          await controller.evaluateJavascript(source: scripts[1]);
          await controller.evaluateJavascript(source: 'window.jsc = jsc;');

          await controller.evaluateJavascript(
            source: 'var module={exports:{}};var exports=module.exports;'
                '${scripts[2]}\nwindow.BGUtils=module.exports;',
          );
          await controller.evaluateJavascript(source: scripts[3]);
          await controller.evaluateJavascript(source: scripts[4]);
          ready.complete();
        } catch (e) {
          if (!ready.isCompleted) ready.completeError(e);
        }
      },
      initialUrlRequest: URLRequest(url: WebUri(_bridgeUrl)),
    );

    _webView = webView;
    // ignore: avoid_print
    print('YouFree JS: subindo webview');
    await webView.run();
    await ready.future.timeout(
      _bootTimeout,
      onTimeout: () => throw Exception('WebView não inicializou a tempo'),
    );

    // ignore: avoid_print
    print('YouFree JS: webview pronta, preparando player');
    final playerJs = await _fetchPlayerScript();
    final prepared = await _call(
      '__youfreePreparePlayer(${jsonEncode(playerJs)})',
    );
    _signatureTimestamp = (prepared['signatureTimestamp'] as num?)?.toInt();
    if (_signatureTimestamp == null) {
      throw Exception('não obtive o signatureTimestamp do player');
    }
  }

  /// Exposes two functions to the page: one returning text, one parsed JSON.
  /// Both run the actual request on the Dart side.
  void _registerFetchBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'youfreeFetch',
      callback: (args) async {
        final url = '${args[0]}';
        final options = args.length > 1 && args[1] is Map
            ? Map<String, dynamic>.from(args[1] as Map)
            : const <String, dynamic>{};

        final headers = <String, String>{};
        final rawHeaders = options['headers'];
        if (rawHeaders is Map) {
          rawHeaders.forEach((key, value) => headers['$key'] = '$value');
        }

        try {
          final response = await _http.request<String>(
            url,
            data: options['body'],
            options: Options(
              method: '${options['method'] ?? 'GET'}',
              headers: headers,
            ),
          );
          return {'status': response.statusCode, 'body': response.data ?? ''};
        } catch (e) {
          return {'status': 0, 'body': '', 'error': '$e'};
        }
      },
    );

    controller.evaluateJavascript(source: _fetchBridgeJs);
  }

  static const _fetchBridgeJs = r"""
    window.__youfreeFetchText = async function (url, options) {
      var r = await window.flutter_inappwebview.callHandler(
        'youfreeFetch', url, options || {});
      if (!r || !r.status) {
        throw new Error('rede: ' + ((r && r.error) || 'sem resposta'));
      }
      return r.body;
    };
    window.__youfreeFetchJson = async function (url, options) {
      return JSON.parse(await window.__youfreeFetchText(url, options));
    };
  """;

  /// Finds the current player build and downloads its script.
  Future<String> _fetchPlayerScript() async {
    final iframeApi = await _http.get<String>('$_origin/iframe_api');
    final body = iframeApi.data ?? '';
    final playerId = (RegExp(r'/player\\?/([0-9a-fA-F]{8})\\?/').firstMatch(body) ??
            RegExp(r'/player/([0-9a-fA-F]{8})/').firstMatch(body))
        ?.group(1);
    if (playerId == null) throw Exception('não achei o id do player');

    final player = await _http.get<String>(
      '$_origin/s/player/$playerId/player_ias.vflset/en_US/base.js',
    );
    final source = player.data;
    if (source == null || source.length < 1000) {
      throw Exception('base.js veio vazio');
    }
    return source;
  }

  /// Every bridge function is async, so this goes through
  /// `callAsyncJavaScript`: `evaluateJavascript` runs a classic script, where
  /// a top-level `await` is a syntax error and a promise comes back unresolved.
  Future<Map<String, dynamic>> _call(String expression) async {
    final controller = _controller;
    if (controller == null) throw Exception('WebView indisponível');

    final outcome = await controller
        .callAsyncJavaScript(functionBody: 'return await $expression;')
        .timeout(_callTimeout);

    if (outcome == null) throw Exception('a ponte JS não respondeu');
    if (outcome.error != null) throw Exception('erro no JS: ${outcome.error}');

    final value = outcome.value;
    if (value == null) throw Exception('a ponte JS devolveu vazio');

    final decoded = value is String ? jsonDecode(value) : value;
    final result = decoded is String
        ? jsonDecode(decoded) as Map<String, dynamic>
        : Map<String, dynamic>.from(decoded as Map);
    if (result['ok'] != true) throw Exception('${result['error']}');
    return result;
  }

  /// Descrambles a `signatureCipher` `s` value.
  @override
  Future<String> solveSignature(String challenge) async {
    await _ensureReady();
    final result = await _call('__youfreeSolve("sig", ${jsonEncode(challenge)})');
    return result['value'] as String;
  }

  /// Descrambles the throttling `n` parameter. Leaving it scrambled makes the
  /// CDN trickle the stream instead of refusing it, which is harder to notice.
  @override
  Future<String> solveN(String challenge) async {
    await _ensureReady();
    final result = await _call('__youfreeSolve("n", ${jsonEncode(challenge)})');
    return result['value'] as String;
  }

  /// Mints a proof-of-origin token bound to [identifier] (the video id).
  @override
  Future<String> mintPoToken(String identifier) async {
    await _ensureReady();
    final result =
        await _call('__youfreeMintPoToken(${jsonEncode(identifier)})');
    return result['poToken'] as String;
  }

  /// Loads the player script and reports its signature timestamp.
  @override
  Future<int> prepare() async {
    await _ensureReady();
    return _signatureTimestamp!;
  }

  Future<void> dispose() async {
    await _webView?.dispose();
    _webView = null;
    _controller = null;
    _booting = null;
  }
}
