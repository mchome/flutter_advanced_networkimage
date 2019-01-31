import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:flutter/services.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';

void main() {
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

    test('=> save and load', () async {
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
      expect(
        await DiskCache().load('ccc'.hashCode.toString()),
        utf8.encode('welcome'),
      );
    });
    test('=> reach maxAge', () async {
      expect(
        await DiskCache().save(
          'fff'.hashCode.toString(),
          utf8.encode('spring'),
          CacheRule(
            storeDirectory: StoreDirectoryType.document,
            maxAge: Duration(
              milliseconds: 1,
            ),
          ),
        ),
        true,
      );
      expect(await DiskCache().load('fff'.hashCode.toString()), null);
    });
    test('=> reach maxEntries', () async {
      DiskCache().maxEntries = 1;
      expect(
        await DiskCache().save(
            'ggg'.hashCode.toString(), utf8.encode('summer'), CacheRule()),
        true,
      );
      expect(
        await DiskCache().save(
            'hhh'.hashCode.toString(), utf8.encode('autumn'), CacheRule()),
        true,
      );
      expect(await DiskCache().load('ggg'.hashCode.toString()), null);
      expect(await DiskCache().load('hhh'.hashCode.toString()),
          utf8.encode('autumn'));
      DiskCache().maxEntries = 5000;
    });
    test('=> reach maxSizeBytes', () async {
      DiskCache().maxSizeBytes = 8;
      expect(
        await DiskCache().save(
            'iii'.hashCode.toString(), utf8.encode('winter'), CacheRule()),
        true,
      );
      expect(
        await DiskCache().save(
            'jjj'.hashCode.toString(), utf8.encode('Monday'), CacheRule()),
        true,
      );
      expect(await DiskCache().load('iii'.hashCode.toString()), null);
      expect(await DiskCache().load('jjj'.hashCode.toString()),
          utf8.encode('Monday'));
      DiskCache().maxSizeBytes = 1000 << 20;
    });
    test('=> evict uid', () async {
      expect(
        await DiskCache().save(
            'kkk'.hashCode.toString(), utf8.encode('Tuesday'), CacheRule()),
        true,
      );
      expect(await DiskCache().load('kkk'.hashCode.toString()),
          utf8.encode('Tuesday'));
      expect(await DiskCache().evict('kkk'.hashCode.toString()), true);
      expect(await DiskCache().load('kkk'.hashCode.toString()), null);
    });
    test('=> clear cache', () async {
      expect(
        await DiskCache().save(
            'lll'.hashCode.toString(), utf8.encode('Wednesday'), CacheRule()),
        true,
      );
      expect(await DiskCache().load('lll'.hashCode.toString()),
          utf8.encode('Wednesday'));
      expect(await DiskCache().clear(), true);
      expect(await DiskCache().load('lll'.hashCode.toString()), null);
    });
    test('=> get cache size', () async {
      expect(await DiskCache().clear(), true);
      expect(
        await DiskCache().save(
            'mmm'.hashCode.toString(), utf8.encode('Thursday'), CacheRule()),
        true,
      );
      expect(
        await DiskCache().save('nnn'.hashCode.toString(), utf8.encode('Friday'),
            CacheRule(storeDirectory: StoreDirectoryType.document)),
        true,
      );
      expect(await DiskCache().load('mmm'.hashCode.toString()),
          utf8.encode('Thursday'));
      expect(await DiskCache().load('nnn'.hashCode.toString()),
          utf8.encode('Friday'));
      expect(
          await DiskCache().cacheSize(), 'Thursday'.length + 'Friday'.length);
      expect(await DiskCache().clear(), true);
      expect(await DiskCache().cacheSize(), 0);
    });
  });
}
