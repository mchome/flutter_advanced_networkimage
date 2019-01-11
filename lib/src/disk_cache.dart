/// WIP, do not use it

library disk_cache;

class DiskCache {
  bool simpleCache = false;
  Map cacheConfig = {
    'maxSize': null,
    'maxEntries': null,
    'maxAge': null,
    'compress': false,
  };
  List cachedFiles = [];

  getFiles(List key) {}

  listFiles() {}

  removeFiles(List key) {}
}

DiskCache diskCache = DiskCache();
