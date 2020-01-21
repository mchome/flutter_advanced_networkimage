import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'package:flutter_advanced_networkimage/src/utils.dart';

void main() {
  group('Download Test', () {
    test('=> good url', () async {
      var url = 'https://flutter.dev/images/flutter-logo-sharing.png';
      var result = (await http.get(url)).bodyBytes;

      expect(
          await loadFromRemote(url, null, 5, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          result);

      url =
          'https://github.com/dart-lang/site-shared/raw/master/src/_assets/image/flutter/logo/default.svg';
      result = (await http.get(url)).bodyBytes;

      expect(
          await loadFromRemote(url, null, 5, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          result);
    });
    test('=> good url with progress', () async {
      var url = 'this is a label';
      var realUrl = 'https://flutter.dev/images/flutter-logo-sharing.png';
      var result = (await http.get(realUrl)).bodyBytes;

      expect(
          await loadFromRemote(
            url,
            null,
            5,
            const Duration(milliseconds: 100),
            1.0,
            const Duration(seconds: 5),
            (_, v) => print(v.length),
            () => Future.value(realUrl),
            printError: true,
          ),
          result);

      url = 'this is another label';
      realUrl =
          'https://github.com/dart-lang/site-shared/raw/master/src/_assets/image/flutter/logo/default.svg';
      result = (await http.get(realUrl)).bodyBytes;

      expect(
          await loadFromRemote(
            url,
            null,
            5,
            const Duration(milliseconds: 100),
            1.0,
            const Duration(seconds: 5),
            (_, v) => print(v.length),
            () => Future.value(realUrl),
            printError: true,
          ),
          result);
    });
    test('=> bad url with skip 404 retry', () async {
      var url =
          'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png';

      expect(
          await loadFromRemote(url, null, 5, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              skipRetryStatusCode: [404], printError: true),
          null);
    });
    test('=> not a url', () async {
      var url = '/GitHub-Marks.png';

      expect(
          await loadFromRemote(url, null, 0, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          null);
    });
  });
  group('Other Test', () {
    test('=> crc32', () {
      expect(crc32(utf8.encode('hello world')), 222957957);
      expect(
          crc32(utf8.encode('The quick brown fox jumps over the lazy dog'))
              .toRadixString(16),
          '414fa339');
    });
    test('=> remove from cache', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          Directory dir = Directory(join(Directory.current.path, 'tmp', 'app'));
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return dir.path;
        } else if (methodCall.method == 'getTemporaryDirectory') {
          Directory dir =
              Directory(join(Directory.current.path, 'tmp', 'temp'));
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return dir.path;
        }
        return null;
      });

      expect(await removeFromCache('hello', useCacheRule: false), false);
      expect(await removeFromCache('world', useCacheRule: true), false);
    });
  });
}
