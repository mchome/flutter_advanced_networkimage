/// WIP, do not use it

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_advanced_networkimage/src/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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
  int maxCounts = 10;

  int get _currentEntries => _metadata.keys.length;
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
    maxEntries = value;
  }

  set maxSizeBytes(int value) {
    assert(value != null);
    assert(value >= 0);
    if (value == maxSizeBytes) return;
    maxSizeBytes = value;
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

  int _currentCounts = 0;
  Future<void> _commitMetaData([bool force = false]) async {
    if (force) {
      _currentCounts = 0;
    } else {
      _currentCounts += 1;
      if (_currentCounts < maxCounts)
        return;
      else
        _currentCounts = 0;
    }
    File path = File(join(
        (await getApplicationDocumentsDirectory()).path, _metadataFilename));
    await path.writeAsString(json.encode(_metadata));
  }

  Future<void> checkFileAge() async {}

  Future<Uint8List> load(String uid) async {
    if (_metadata == null) await _initMetaData();
    if (_metadata.containsKey(uid)) {
      if (!File(_metadata[uid]['path']).existsSync()) {
        _metadata.remove(uid);
        _commitMetaData();
        return null;
      }
      if (DateTime.fromMillisecondsSinceEpoch(
            _metadata[uid]['createdTime'] + _metadata[uid]['maxAge'],
          ).compareTo(DateTime.now()) <
          0) {
        _metadata.remove(uid);
        _commitMetaData();
        return null;
      }
      Uint8List data = await File(_metadata[uid]['path']).readAsBytes();
      if (_metadata[uid]['crc32'] != null &&
          _metadata[uid]['crc32'] == crc32(data)) {
        _metadata.remove(uid);
        _commitMetaData();
        return null;
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

    await _commitMetaData(true);

    return true;
  }

  Future<bool> evict(String uid) async {
    return null;
  }

  Future<bool> clear() async {
    return null;
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
