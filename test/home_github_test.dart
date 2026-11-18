import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nb_net/flutter_net.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/constants.dart' show readmeUrlGithub, oasxRelease;
import 'package:oasx/controller/settings.dart';

class TestSettings extends GetxController implements SettingsController {
  @override
  String temporaryDirectory = './';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GithubAdapter implements HttpClientAdapter {
  int status = 404;
  Object payload = {'message': 'Not Found'};
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri);
    return ResponseBody.fromString(jsonEncode(payload), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late GithubAdapter adapter;

  setUpAll(() {
    final settings = TestSettings()..temporaryDirectory = './';
    // Register without starting SettingsController's platform initialization.
    Get.lazyPut<SettingsController>(() => settings);
    client = ApiClient();
    NetOptions.instance.dio.interceptors.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => 'wifi',
    );
  });

  setUp(() {
    adapter = GithubAdapter();
    NetOptions.instance.dio.httpClientAdapter = adapter;
  });

  test('README uses maintained repository and decodes successful response',
      () async {
    adapter.status = 200;
    adapter.payload = {
      'content': base64Encode(utf8.encode('# Current README'))
    };
    final readme = await client.getGithubReadme();
    expect(readme.content, '# Current README');
    expect(adapter.requests.single.toString(), readmeUrlGithub);
    expect(adapter.requests.single.path,
        '/repos/nearaura/OnmyojiAutoScript/readme');
  });

  test('missing release returns empty model without trying to show a snackbar',
      () async {
    final version = await client.getGithubVersion();
    expect(version.version, isNull);
    expect(
        adapter.requests.single.path, '/repos/nearaura/OASX/releases/latest');
    expect(Get.isSnackbarOpen, isFalse);
  });

  test('unavailable README falls back without a global network error',
      () async {
    final readme = await client.getGithubReadme();
    expect(readme.content, isNull);
    expect(Get.isSnackbarOpen, isFalse);
  });

  test('optional requests tolerate offline errors and preserve error result',
      () async {
    final result = await client.request<String>(
      () async => throw StateError('offline'),
      showErrors: false,
    );
    expect(result.isSuccess, isFalse);
    expect(result.error, contains('offline'));
    expect(Get.isSnackbarOpen, isFalse);
  });

  test('successful release check decodes maintained repository response',
      () async {
    adapter.status = 200;
    adapter.payload = {
      'tag_name': 'v0.3.3',
      'body': 'Changes',
      'updated_at': '2026-11-17T00:00:00Z'
    };
    final version = await client.getGithubVersion();
    expect(version.version, 'v0.3.3');
    expect(oasxRelease, 'https://github.com/nearaura/OASX/releases');
  });
}
