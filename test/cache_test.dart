import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test_api/test_api.dart';

main() {
  group('Cache Test', () {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        Directory dir = Directory(join(Directory.current.path, 'tmp', 'app'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir.path;
      } else if (methodCall.method == 'getTemporaryDirectory') {
        Directory dir = Directory(join(Directory.current.path, 'tmp', 'temp'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir.path;
      }
      return null;
    });

    test('=> dummy1', () async {
      print(await getApplicationDocumentsDirectory());
      print(await getTemporaryDirectory());
    });
    test('=> dummy2', () async {
      expect(
        await DiskCache().save('aaa'.hashCode.toString(), utf8.encode('hello'),
            CacheRule(checksum: true)),
        true,
      );
      expect(
        await DiskCache().save('bbb'.hashCode.toString(), utf8.encode('world'),
            CacheRule(checksum: true)),
        true,
      );
      expect(
        await DiskCache().save('ccc'.hashCode.toString(),
            utf8.encode('welcome'), CacheRule(checksum: true)),
        true,
      );
      expect(
        await DiskCache().save('ddd'.hashCode.toString(), utf8.encode('to'),
            CacheRule(checksum: true)),
        true,
      );
      expect(
        await DiskCache().save('eee'.hashCode.toString(),
            utf8.encode('flutter'), CacheRule(checksum: true)),
        true,
      );
      expect(await DiskCache().load('aaa'.hashCode.toString()), utf8.encode('hello'));
    });
  });
}
