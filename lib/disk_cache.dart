/// WIP

library disk_cache;

class Cache {
  bool simpleCache = true;
  Map cacheConfig = {};
  List cachedFiles = [];

  getFiles(List key) {}

  listFiles() {}

  removeFiles(List key) {}
}

Cache cache = Cache();
