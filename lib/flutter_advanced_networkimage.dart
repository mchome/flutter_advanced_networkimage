library advanced_networkimage;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;
import 'dart:ui' show hashValues;

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:quiver/collection.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_advanced_networkimage/utils.dart';

/// NOTE: memory cache: LruMap(maximumSize: 1024)
///  {
///    '$uid(image_url)': '$ImageData',
///    ...
///  }

class AdvancedNetworkImage extends ImageProvider<AdvancedNetworkImage> {
  const AdvancedNetworkImage(
    this.url, {
    this.scale: 1.0,
    this.header,
    this.useMemoryCache: true,
    this.useDiskCache: false,
    this.retryLimit: 5,
    this.retryDuration: const Duration(milliseconds: 500),
    this.timeoutDuration: const Duration(seconds: 5),
    this.loadedCallback,
    this.loadFailedCallback,
  })  : assert(url != null),
        assert(scale != null),
        assert(useMemoryCache != null),
        assert(useDiskCache != null),
        assert(retryLimit != null && retryLimit != 0),
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

  /// The callback will be executed when the image loaded.
  final Function loadedCallback;

  /// The callback will be executed when the iamge failed to load.
  final Function loadFailedCallback;

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return new SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(AdvancedNetworkImage key) {
    return MultiFrameImageStreamCompleter(
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

    String uId = _uid(key.url);

    try {
      if (useMemoryCache &&
          _imageMemoryCache != null &&
          _imageMemoryCache.containsKey(uId)) {
        if (useDiskCache) _loadFromDiskCache(key, uId);
        if (key.loadedCallback != null) key.loadedCallback();
        return await ui.instantiateImageCodec(_imageMemoryCache[uId]);
      }
    } catch (e) {
      debugPrint('useMemoryCache: ' + e.toString());
    }

    try {
      if (useDiskCache) {
        Uint8List _diskCache = await _loadFromDiskCache(key, uId);
        if (useMemoryCache) _imageMemoryCache[uId] = _diskCache;
        if (key.loadedCallback != null) key.loadedCallback();
        return await ui.instantiateImageCodec(_diskCache);
      }
    } catch (e) {
      debugPrint('useDiskCache: ' + e.toString());
    }

    try {
      Uint8List imageData = await _loadFromRemote(
          key.url, key.header, key.retryLimit, key.retryDuration);
      if (imageData != null) {
        if (useMemoryCache) _imageMemoryCache[uId] = imageData;
        if (key.loadedCallback != null) key.loadedCallback();
        return await ui.instantiateImageCodec(imageData);
      }
    } catch (e) {
      debugPrint('remote: ' + e.toString());
    }

    debugPrint('Failed to load $url.');
    if (key.loadFailedCallback != null) key.loadFailedCallback();
    return await ui.instantiateImageCodec(featureImage);
  }

  /// Load the disk cache
  ///
  /// Check the following condition:
  /// 1. Check if cache directory exist. If not exist, create it.
  /// 2. Check if cached file([uId]) exist. If yes, load the cache,
  ///   otherwise go to download step.
  Future<Uint8List> _loadFromDiskCache(
      AdvancedNetworkImage key, String uId) async {
    Directory _cacheImagesDirectory =
        new Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
    if (_cacheImagesDirectory.existsSync()) {
      File _cacheImageFile = new File(join(_cacheImagesDirectory.path, uId));
      if (_cacheImageFile.existsSync()) {
        return await _cacheImageFile.readAsBytes();
      }
    } else {
      await _cacheImagesDirectory.create();
    }

    Uint8List imageData = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageData != null) {
      await (new File(join(_cacheImagesDirectory.path, uId)))
          .writeAsBytes(imageData);
      return imageData;
    }

    return null;
  }

  /// Fetch the image from network.
  Future<Uint8List> _loadFromRemote(String url, Map<String, String> header,
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
      debugPrint('Retry failed!');
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
        return _response.bodyBytes;
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
        useDiskCache == typedOther.useDiskCache &&
        retryLimit == typedOther.retryLimit &&
        retryDuration == typedOther.retryDuration;
  }

  @override
  int get hashCode => hashValues(url, scale, header, useDiskCache, retryLimit,
      retryDuration, timeoutDuration);
  @override
  String toString() => '$runtimeType('
      '"$url",'
      'scale: $scale,'
      'header: $header,'
      'useDiskCache:$useDiskCache,'
      'retryLimit:$retryLimit,'
      'retryDuration:$retryDuration,'
      'timeoutDuration:$timeoutDuration'
      ')';
}

/// Clear the disk cache directory then return if it succeed.
Future<bool> clearDiskCachedImages() async {
  Directory _cacheImagesDirectory =
      new Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
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
      new Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
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

/// Use a [LruMap] to store the custom memory cache.
LruMap<String, Uint8List> _imageMemoryCache = new LruMap(maximumSize: 1024);
