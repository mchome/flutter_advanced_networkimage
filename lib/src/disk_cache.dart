/// WIP, do not use it

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart' show crc32;

enum StoreDirectoryType {
  temporary,
  document,
}

class DiskCache {
  static final DiskCache _instance = DiskCache._internal();
  factory DiskCache() => _instance;
  DiskCache._internal();

  int get maxEntries => _maxEntries;
  int _maxEntries = 5000;
  int get maxSizeBytes => _maxSizeBytes;
  int _maxSizeBytes = 1000 << 20; // 1 GiB
  int maxCommitOps = 10;

  int _currentOps = 0;
  int get _currentEntries => _metadata != null ? _metadata.keys.length : 0;
  int get _currentSizeBytes {
    int size = 0;
    _metadata.values.forEach((item) => size += item['size']);
    return size;
  }

  Map<String, dynamic> _metadata;

  set maxEntries(int value) {
    assert(value != null);
    assert(value >= 0);
    if (value == maxEntries) return;
    _maxEntries = value;
  }

  set maxSizeBytes(int value) {
    assert(value != null);
    assert(value >= 0);
    if (value == maxSizeBytes) return;
    _maxSizeBytes = value;
  }

  static const String _metadataFilename = 'imagecache_metadata.json';

  Future<void> _initMetaData() async {
    Directory dir = await getApplicationDocumentsDirectory();
    File path = File(join(dir.path, _metadataFilename));
    try {
      if (path.existsSync())
        _metadata = json.decode(await path.readAsString());
      else
        _metadata = {};
    } catch (_) {
      _metadata = {};
    }
  }

  Future<void> _commitMetaData([bool force = false]) async {
    if (force) {
      _currentOps = 0;
    } else {
      _currentOps += 1;
      if (_currentOps < maxCommitOps)
        return;
      else
        _currentOps = 0;
    }
    File path = File(join(
        (await getApplicationDocumentsDirectory()).path, _metadataFilename));
    await path.writeAsString(json.encode(_metadata));
  }

  Future<void> keepCacheHealth() async {
    _metadata.removeWhere((k, v) {
      if (!File(v['path']).existsSync()) return true;
      if (DateTime.fromMillisecondsSinceEpoch(v['createdTime'] + v['maxAge'])
              .compareTo(DateTime.now()) <
          0) {
        File(v['path']).deleteSync();
        return true;
      }
      Uint8List data = File(v['path']).readAsBytesSync();
      if (v['crc32'] != null && v['crc32'] != crc32(data)) {
        File(v['path']).deleteSync();
        return true;
      }
    });
    await _checkCacheSize();
    await _commitMetaData();
  }

  Future<Uint8List> load(String uid) async {
    if (_metadata == null) await _initMetaData();
    if (_metadata.containsKey(uid)) {
      if (!File(_metadata[uid]['path']).existsSync()) {
        _metadata.remove(uid);
        await _commitMetaData();
        return null;
      }
      if (DateTime.fromMillisecondsSinceEpoch(
            _metadata[uid]['createdTime'] + _metadata[uid]['maxAge'],
          ).compareTo(DateTime.now()) <
          0) {
        await File(_metadata[uid]['path']).delete();
        _metadata.remove(uid);
        await _commitMetaData();
        return null;
      }
      Uint8List data = await File(_metadata[uid]['path']).readAsBytes();
      if (_metadata[uid]['crc32'] != null &&
          _metadata[uid]['crc32'] != crc32(data)) {
        await File(_metadata[uid]['path']).delete();
        _metadata.remove(uid);
        await _commitMetaData();
        return null;
      }
      if (_currentEntries >= maxEntries || _currentSizeBytes >= maxSizeBytes) {
        _metadata[uid] = _metadata.remove(uid);
        await _commitMetaData();
      }
      return data;
    }
    return null;
  }

  Future<bool> save(String uid, Uint8List data, CacheRule rule) async {
    if (_metadata == null) await _initMetaData();
    Directory dir = Directory(join(
        (rule.storeDirectory == StoreDirectoryType.temporary
                ? await getTemporaryDirectory()
                : await getApplicationDocumentsDirectory())
            .path,
        'imagecache'));

    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
      await File(join(dir.path, uid)).writeAsBytes(data);

      Map<String, dynamic> metadata = {
        'path': join(dir.path, uid),
        'createdTime': DateTime.now().millisecondsSinceEpoch,
        'crc32': rule.checksum ? crc32(data) : null,
        'size': data.lengthInBytes,
        'maxAge': rule.maxAge.inMilliseconds,
      };
      _metadata[uid] = metadata;
      await _checkCacheSize();
      await _commitMetaData(true);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkCacheSize() async {
    while (_currentEntries > maxEntries || _currentSizeBytes > maxSizeBytes) {
      String key = _metadata.keys.first;
      if (File(_metadata[key]['path']).existsSync())
        await File(_metadata[key]['path']).delete();
      _metadata.remove(key);
    }
  }

  Future<bool> evict(String uid) async {
    if (_metadata == null) await _initMetaData();
    try {
      if (_metadata.containsKey(uid) &&
          File(_metadata[uid]['path']).existsSync()) {
        await File(_metadata[uid]['path']).delete();
        _metadata.remove(uid);
        await _commitMetaData();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clear() async {
    try {
      Directory tempDir =
          Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
      Directory appDir = Directory(
          join((await getApplicationDocumentsDirectory()).path, 'imagecache'));
      File metadataFile = File(join(
          (await getApplicationDocumentsDirectory()).path, _metadataFilename));
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      if (appDir.existsSync()) await appDir.delete(recursive: true);
      if (metadataFile.existsSync()) await metadataFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class CacheRule {
  const CacheRule({
    this.maxAge = const Duration(days: 30),
    this.storeDirectory: StoreDirectoryType.temporary,
    this.checksum: false,
  })  : assert(maxAge != null),
        assert(storeDirectory != null),
        assert(checksum != null);

  final Duration maxAge;
  final StoreDirectoryType storeDirectory;
  final bool checksum;
}
