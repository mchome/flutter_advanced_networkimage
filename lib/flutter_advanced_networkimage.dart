library advanced_networkimage;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiver/collection.dart';

/// NOTE: memory cache: LruMap(maximumSize: 128)
///  {
///    '$uid(image_url)': '$ImageData',
///    ...
///  }

/// NOTE: disk cache
/// CachedImageFilename: uid(part of hash hexString with imageUrl)
/// MetaDataFilename: getApplicationDocumentsDirectory + '/imagecache/' + 'CachedImageInfo.json'
///  {
///    '$uid(image_url)': '$etag',
///    ...
///  }

class AdvancedNetworkImage extends ImageProvider<AdvancedNetworkImage> {
  const AdvancedNetworkImage(
    this.url, {
    this.scale: 1.0,
    this.header,
    this.useMemoryCache: true,
    this.useDiskCache: false,
    this.retryLimit: 20,
    this.retryDuration: const Duration(milliseconds: 500),
    this.timeoutDuration: const Duration(seconds: 2),
  })
      : assert(url != null),
        assert(scale != null),
        assert(useDiskCache != null),
        assert(retryLimit != null),
        assert(retryDuration != null);

  /// The URL from which the image will be fetched.
  final String url;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The HTTP headers that will be used with [http] to fetch image from network.
  final Map<String, String> header;

  /// The flag control the memory cache will be used or not.
  final bool useMemoryCache;

  /// The flag control the disk cache will be used or not.
  final bool useDiskCache;

  /// The retry limit will be used to limit the retry attempts.
  final int retryLimit;

  /// The retry duration will give the interval between the retry.
  final Duration retryDuration;

  /// The timeout duration will give the timeout to a fetching function.
  final Duration timeoutDuration;

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return new SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(AdvancedNetworkImage key) {
    return new OneFrameImageStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Image provider: $this');
      information.write('Image provider: $key');
    });
  }

  Future<ImageInfo> _loadAsync(AdvancedNetworkImage key) async {
    assert(key == this);

    String uId = _uid(key.url);
    if (useMemoryCache &&
        _imageMemoryCache != null &&
        _imageMemoryCache.containsKey(uId)) {
      if (useDiskCache) _loadFromDiskCache(key, uId);
      return await _decodeImageData(_imageMemoryCache[uId], key.scale);
    }
    try {
      if (useDiskCache)
        return await _decodeImageData(
            await _loadFromDiskCache(key, uId), key.scale);
    } catch (_) {}

    Map imageInfo = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageInfo != null) {
      if (useMemoryCache) _imageMemoryCache[uId] = imageInfo['ImageData'];
      return await _decodeImageData(imageInfo['ImageData'], key.scale);
    }

    return null;
  }

  /// Load the disk cache
  ///
  /// Check the following condition:
  /// 1. Check if cache directory exist. If not exist, create it.
  /// 2. Check if cache metadata file exist. If not exist, go to download step.
  /// 3. Check if [_diskCacheInfo] is empty. If is, load it.
  /// 4. Check if [_diskCacheInfo] contains [uId]. If not, go to download step.
  /// 5. Check if [_diskCacheInfo][uId] is empty. If is, load the cache.
  /// 6. Check if [_responseHeaders] contains eTag. If not, load the cache.
  /// 7. Check if [_responseHeaders] match with [_diskCacheInfo][uId]. If yes,
  ///   load the cache, otherwise got to download step.
  Future<Uint8List> _loadFromDiskCache(
      AdvancedNetworkImage key, String uId) async {
    Directory _cacheImagesDirectory = new Directory(
        join((await getApplicationDocumentsDirectory()).path, 'imagecache'));
    File _cacheImagesInfoFile =
        new File(join(_cacheImagesDirectory.path, 'CachedImageInfo.json'));
    if (_cacheImagesDirectory.existsSync()) {
      if (_cacheImagesInfoFile.existsSync()) {
        if (_diskCacheInfo == null || _diskCacheInfo.length == 0) {
          _diskCacheInfo = JSON.decode(
              (await _cacheImagesInfoFile.readAsString(encoding: utf8)) ?? {});
        }
        try {
          if (_diskCacheInfo.containsKey(uId)) {
            if (_diskCacheInfo[uId].length > 0) {
              Map<String, String> _responseHeaders = (await http
                      .head(url, headers: header)
                      .timeout(const Duration(milliseconds: 500)))
                  .headers;
              if (_responseHeaders.containsKey('etag')) {
                String _freshETag = _responseHeaders['etag'];
                if (_diskCacheInfo[uId] == _freshETag) {
                  return await (new File(join(_cacheImagesDirectory.path, uId)))
                      .readAsBytes();
                }
              } else {
                return await (new File(join(_cacheImagesDirectory.path, uId)))
                    .readAsBytes();
              }
            } else {
              return await (new File(join(_cacheImagesDirectory.path, uId)))
                  .readAsBytes();
            }
          }
        } catch (_) {
          return await (new File(join(_cacheImagesDirectory.path, uId)))
              .readAsBytes();
        }
      }
    } else {
      await _cacheImagesDirectory.create();
    }

    Map imageInfo = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageInfo != null) {
      _diskCacheInfo[uId] = imageInfo['Etag'];
      await (new File(join(_cacheImagesDirectory.path, uId)))
          .writeAsBytes(imageInfo['ImageData']);
      await (new File(_cacheImagesInfoFile.path).writeAsString(
          JSON.encode(_diskCacheInfo),
          mode: FileMode.WRITE,
          encoding: utf8));
      return imageInfo['ImageData'];
    }

    return null;
  }

  /// Fetch the image from network.
  Future<Map> _loadFromRemote(String url, Map<String, String> header,
      int retryLimit, Duration retryDuration) async {
    /// Retry mechanism.
    Future<T> retry<T>(
        Future f(), int retryLimit, Duration retryDuration) async {
      for (int t = 0; t < retryLimit; t++) {
        try {
          return await f();
        } catch (_) {
          await new Future.delayed(retryDuration);
        }
      }
      print('retry failed');
      return null;
    }

    http.Response _response;
    _response = await retry(() async {
      if (header != null)
        return await http.get(url, headers: header).timeout(timeoutDuration);
      else
        return await http.get(url).timeout(timeoutDuration);
    }, retryLimit, retryDuration);
    if (_response != null) {
      if (_response.statusCode == 200) {
        return {
          'ImageData': _response.bodyBytes,
          'Etag': _response.headers.containsKey('etag')
              ? _response.headers['etag']
              : ''
        };
      }
    }

    return null;
  }

  Future<ImageInfo> _decodeImageData(
      Uint8List imageData, double scaleSize) async {
    return new ImageInfo(
        image: await decodeImageFromList(imageData), scale: scaleSize);
  }

  String _uid(String str) =>
      md5.convert(UTF8.encode(str)).toString().toLowerCase().substring(0, 9);

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkImage typedOther = other;
    return url == typedOther.url &&
        scale == typedOther.scale &&
        header == typedOther.header &&
        useMemoryCache == typedOther.useMemoryCache &&
        useDiskCache == typedOther.useDiskCache &&
        retryLimit == typedOther.retryLimit &&
        retryDuration == typedOther.retryDuration;
  }

  @override
  int get hashCode => hashValues(url, scale, header, useMemoryCache,
      useDiskCache, retryLimit, retryDuration, timeoutDuration);
  @override
  String toString() => '$runtimeType('
      '"$url",'
      'scale: $scale,'
      'header: $header,'
      'useMemCache: $useMemoryCache,'
      'useDiskCache:$useDiskCache,'
      'retryLimit:$retryLimit,'
      'retryDuration:$retryDuration,'
      'timeoutDuration:$timeoutDuration'
      ')';
}

/// Clear the disk cache directory then return if it succeed.
Future<bool> clearDiskCachedImages() async {
  Directory _cacheImagesDirectory = new Directory(
      join((await getApplicationDocumentsDirectory()).path, 'imagecache'));
  try {
    await _cacheImagesDirectory.delete(recursive: true);
  } catch (_) {
    return false;
  }
  return true;
}

/// Return the disk cache directory size.
Future<int> getDiskCachedImagesSize() async {
  Directory _cacheImagesDirectory = new Directory(
      join((await getApplicationDocumentsDirectory()).path, 'imagecache'));
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

/// Disk cache info value.
Map<String, String> _diskCacheInfo = {};
/// Use a [LruMap] to store the memory cache.
LruMap<String, Uint8List> _imageMemoryCache = new LruMap(maximumSize: 128);
