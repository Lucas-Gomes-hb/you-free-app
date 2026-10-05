import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youfree/app/app_mode.dart';
import 'package:youfree/data/services/api_service.dart';
import 'package:youfree/data/services/remote_content_source.dart';

/// Minimal stand-in for the YouFree API that records the headers it received.
class _FakeApi {
  _FakeApi._(this._server, this.receivedModes);

  static Future<_FakeApi> start() async {
    final receivedModes = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      receivedModes.add(request.headers.value('X-YouFree-Mode') ?? '<ausente>');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'results': [], 'count': 0}));
      await request.response.close();
    });
    return _FakeApi._(server, receivedModes);
  }

  final HttpServer _server;
  final List<String> receivedModes;

  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late _FakeApi api;

  setUp(() async => api = await _FakeApi.start());
  tearDown(() async => api.stop());

  test('remote source defaults to music mode', () {
    final source = RemoteContentSource(api.baseUrl);
    expect(source.appMode, AppMode.music);
  });

  test('setting the same mode twice keeps it stable', () {
    final source = RemoteContentSource(api.baseUrl);
    source.appMode = AppMode.music;
    expect(source.appMode, AppMode.music);
  });

  test('ApiService.setAppMode reaches the remote source', () {
    final service = ApiService(api.baseUrl);
    service.setAppMode(AppMode.video);
    expect(service.appMode, AppMode.video);
  });

  test('requests carry X-YouFree-Mode: music by default', () async {
    final source = RemoteContentSource(api.baseUrl);
    await source.getHomeFeed();
    expect(api.receivedModes, ['music']);
  });

  test('switching to video mode changes the header on later requests', () async {
    final source = RemoteContentSource(api.baseUrl);
    await source.getHomeFeed();
    source.appMode = AppMode.video;
    await source.getHomeFeed();
    expect(api.receivedModes, ['music', 'video']);
  });

  test('the header follows the mode across several endpoints', () async {
    final source = RemoteContentSource(api.baseUrl);
    source.appMode = AppMode.video;
    await source.search('test');
    await source.getSuggestions('te');
    expect(api.receivedModes, ['video', 'video']);
  });
}
