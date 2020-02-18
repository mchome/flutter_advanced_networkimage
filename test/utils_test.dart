import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/painting.dart' show Offset;

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
    test('=> uid', () {
      expect(uid('hello world'), '1045060183');
      expect(uid('The quick brown fox jumps over the lazy dog'), '295604725');
    });
    test('=> DoubleTween', () {
      final DoubleTween tween = DoubleTween(begin: 2, end: 7);
      expect(tween.lerp(0.3), 3.5);
      expect(tween.lerp(0.9), 6.5);
    });
    test('=> OffsetTween', () {
      final Offset a = Offset(1, 2);
      final Offset b = Offset(5, 1);
      final OffsetTween tween = OffsetTween(begin: a, end: b);
      expect(tween.lerp(0.1), Offset(1.4, 1.9));
      expect(tween.lerp(0.6), Offset(3.4, 1.4));
    });
  });
}
