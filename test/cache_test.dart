import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestWidgetsFlutterBinding, throwsAssertionError;

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      Directory dir =
          Directory(join(Directory.current.path, 'test', 'tmp', 'app'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir.path;
    } else if (methodCall.method == 'getTemporaryDirectory') {
      Directory dir =
          Directory(join(Directory.current.path, 'test', 'tmp', 'temp'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir.path;
    }
    return null;
  });

  group('Cache Test', () {
    test('=> non-null test', () async {
      await DiskCache().keepCacheHealth();

      expect(() => CacheRule(maxAge: null), throwsAssertionError);
      expect(() => CacheRule(storeDirectory: null), throwsAssertionError);
      expect(() => CacheRule(checksum: null), throwsAssertionError);

      expect(() => DiskCache()..maxEntries = null, throwsAssertionError);
      expect(() => DiskCache()..maxSizeBytes = null, throwsAssertionError);
      expect(() => DiskCache()..maxCommitOps = null, throwsAssertionError);

      expect(() => DiskCache()..maxEntries = -1, throwsAssertionError);
      expect(() => DiskCache()..maxSizeBytes = -1, throwsAssertionError);
      expect(() => DiskCache()..maxCommitOps = -1, throwsAssertionError);
    });
    test('=> save and load', () async {
      DiskCache().printError = true;

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
        await DiskCache().load('aaa'.hashCode.toString()),
        utf8.encode('hello'),
      );
      expect(
        await DiskCache().load('bbb'.hashCode.toString()),
        utf8.encode('world'),
      );
      expect(
        await DiskCache().load('ccc'.hashCode.toString()),
        utf8.encode('welcome'),
      );
      expect(
        await DiskCache().load('ddd'.hashCode.toString()),
        utf8.encode('to'),
      );
      expect(
        await DiskCache().load('eee'.hashCode.toString()),
        utf8.encode('flutter'),
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
      expect(
          await DiskCache().load('fff'.hashCode.toString(),
              rule: CacheRule(
                storeDirectory: StoreDirectoryType.document,
                maxAge: Duration(seconds: 1),
              )),
          utf8.encode('spring'));
      expect(await DiskCache().load('fff'.hashCode.toString(), force: true),
          utf8.encode('spring'));
      expect(await DiskCache().load('fff'.hashCode.toString()), null);

      expect(
        await DiskCache().save(
          'fff'.hashCode.toString(),
          utf8.encode('spring'),
          CacheRule(
            storeDirectory: StoreDirectoryType.document,
            maxAge: Duration(
              seconds: 1,
            ),
          ),
        ),
        true,
      );
      expect(
          await DiskCache().load('fff'.hashCode.toString(),
              rule: CacheRule(
                storeDirectory: StoreDirectoryType.document,
                maxAge: Duration(milliseconds: 1),
              )),
          null);
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
      expect(await DiskCache().evict('kkk'.hashCode.toString()), false);
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
    test('=> keep cache health', () async {
      expect(await DiskCache().clear(), true);
      expect(await DiskCache().cacheSize(), 0);

      expect(
        await DiskCache().save(
            'ooo'.hashCode.toString(), utf8.encode('Saturday'), CacheRule()),
        true,
      );
      expect(await DiskCache().load('ooo'.hashCode.toString()),
          utf8.encode('Saturday'));
      var file = File(
          join((await getTemporaryDirectory()).path, 'imagecache', uid('ooo')));
      await DiskCache().keepCacheHealth();
      expect(file.existsSync(), true);
      file.deleteSync();
      expect(file.existsSync(), false);
      expect(DiskCache().currentEntries, 1);
      await DiskCache().keepCacheHealth();
      expect(DiskCache().currentEntries, 0);

      expect(
        await DiskCache().save(
            'ooo'.hashCode.toString(),
            utf8.encode('Saturday'),
            CacheRule(maxAge: const Duration(milliseconds: 1))),
        true,
      );
      expect(file.existsSync(), true);
      expect(DiskCache().currentEntries, 1);
      await DiskCache().keepCacheHealth();
      expect(file.existsSync(), false);
      expect(DiskCache().currentEntries, 0);

      expect(await DiskCache().clear(), true);
      expect(await DiskCache().cacheSize(), 0);
    });
    test('=> remove from cache', () async {
      expect(await removeFromCache('hello', useCacheRule: false), false);
      expect(await removeFromCache('world', useCacheRule: true), false);
    });
  });
}
