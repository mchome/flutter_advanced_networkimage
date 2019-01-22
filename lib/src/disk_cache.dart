/// WIP, do not use it

library disk_cache;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

enum StoreDirectoryType {
  document,
  temporary,
}

class DiskCache {
  static final DiskCache _instance = DiskCache._internal();
  factory DiskCache() => _instance;
  DiskCache._internal();

  Database _db;
  StoreDirectoryType directoryType = StoreDirectoryType.temporary;

  Future<Database> get db async {
    if (_db != null) return _db;
    _db = await _initDb();
    return _db;
  }

  Future<Database> _initDb() async {
    String path = join(
        (directoryType == StoreDirectoryType.temporary
                ? await getTemporaryDirectory()
                : await getApplicationDocumentsDirectory())
            .path,
        'image_cache.db');
    return await databaseFactoryIo.openDatabase(path);
  }
}
