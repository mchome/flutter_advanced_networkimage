library advanced_provider;

export 'package:flutter_advanced_networkimage/src/flutter_advanced_networkimage.dart';
export 'package:flutter_advanced_networkimage/src/flutter_advanced_networksvg.dart';

import 'dart:io';
import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Clear the disk cache directory then return if it succeed.
Future<bool> clearDiskCachedImages() async {
  Directory _cacheImagesDirectory =
      Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
  try {
    await _cacheImagesDirectory.delete(recursive: true);
  } catch (_) {
    return false;
  }
  return true;
}

/// Return the disk cache directory size.
Future<int> getDiskCachedImagesSize() async {
  Directory _cacheImagesDirectory =
      Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
  int size = 0;
  try {
    _cacheImagesDirectory
        .listSync()
        .forEach((var file) => size += file.statSync().size);
    return size;
  } catch (_) {
    return null;
  }
}
