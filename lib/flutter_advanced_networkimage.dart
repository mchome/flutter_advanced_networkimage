library advanced_networkimage;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

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
    this.retryLimit: 10,
    this.retryDuration: const Duration(milliseconds: 500),
    this.timeoutDuration: const Duration(seconds: 5),
    this.fallbackImageBytes,
  })  : assert(url != null),
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

  /// The retry duration will give the interval between the retries.
  final Duration retryDuration;

  /// The timeout duration will give the timeout to a fetching function.
  final Duration timeoutDuration;

  /// The image bytes will display when the network image failed to loaded.
  final Uint8List fallbackImageBytes;

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return new SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(AdvancedNetworkImage key) {
    return new MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: (StringBuffer information) {
        information.writeln('Image provider: $this');
        information.write('Image provider: $key');
      },
    );
  }

  Future<ui.Codec> _loadAsync(AdvancedNetworkImage key) async {
    assert(key == this);

    /// Minimum image.
    Uint8List _minimumImage = Uint8List.fromList([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,2,0,0,0,144,119,83,222,0,0,0,1,115,82,71,66,0,174,206,28,233,0,0,0,4,103,65,77,65,0,0,177,143,11,252,97,5,0,0,0,9,112,72,89,115,0,0,14,195,0,0,14,195,1,199,111,168,100,0,0,0,12,73,68,65,84,24,87,99,248,255,255,63,0,5,254,2,254,167,53,129,132,0,0,0,0,73,69,78,68,174,66,96,130]);

    String uId = _uid(key.url);
    if (useMemoryCache &&
        _imageMemoryCache != null &&
        _imageMemoryCache.containsKey(uId)) {
      if (useDiskCache) _loadFromDiskCache(key, uId);
      return await ui.instantiateImageCodec(_imageMemoryCache[uId]);
    }
    try {
      if (useDiskCache)
        return await ui
            .instantiateImageCodec(await _loadFromDiskCache(key, uId));
    } catch (_) {}

    Map imageInfo = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageInfo != null) {
      if (useMemoryCache) _imageMemoryCache[uId] = imageInfo['ImageData'];
      return await ui.instantiateImageCodec(imageInfo['ImageData']);
    }

    if (key.fallbackImageBytes != null) {
      return await ui.instantiateImageCodec(key.fallbackImageBytes);
    }

    print('$url is an empty file.');
    return await ui.instantiateImageCodec(_minimumImage);
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
        join((await getTemporaryDirectory()).path, 'imagecache'));
    File _cacheImagesInfoFile =
        new File(join(_cacheImagesDirectory.path, 'CachedImageInfo.json'));
    if (_cacheImagesDirectory.existsSync()) {
      if (_cacheImagesInfoFile.existsSync()) {
        if (_diskCacheInfo == null || _diskCacheInfo.length == 0) {
          _diskCacheInfo = json.decode(
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
          json.encode(_diskCacheInfo),
          mode: FileMode.write,
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
      print('Retry failed!');
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

  String _uid(String str) =>
      md5.convert(utf8.encode(str)).toString().toLowerCase().substring(0, 9);

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
      join((await getTemporaryDirectory()).path, 'imagecache'));
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
