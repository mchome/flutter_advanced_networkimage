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
import 'package:path_provider/path_provider.dart';

import 'package:flutter_advanced_networkimage/utils.dart';

class AdvancedNetworkImage extends ImageProvider<AdvancedNetworkImage> {
  const AdvancedNetworkImage(
    this.url, {
    this.scale: 1.0,
    this.header,
    this.useDiskCache: false,
    this.retryLimit: 5,
    this.retryDuration: const Duration(milliseconds: 500),
    this.timeoutDuration: const Duration(seconds: 5),
    this.loadedCallback,
    this.loadFailedCallback,
    this.fallbackImage,
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

  /// The callback will be executed when the image failed to load.
  final Function loadFailedCallback;

  /// The image will be displayed when the image failed to load.
  final Uint8List fallbackImage;

  Future<String> get cachedPath async {
    Directory _cacheImagesDirectory =
        Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
    String uId = _uid(url);

    return useDiskCache
        ? File(join(_cacheImagesDirectory.path, uId)).path
        : null;
  }

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AdvancedNetworkImage>(this);
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
      if (useDiskCache) {
        Uint8List _diskCache = await _loadFromDiskCache(key, uId);
        if (key.loadedCallback != null) key.loadedCallback();
        return await ui.instantiateImageCodec(_diskCache);
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    Uint8List imageData = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageData != null) {
      if (key.loadedCallback != null) key.loadedCallback();
      try {
        return await ui.instantiateImageCodec(imageData);
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    debugPrint('Failed to load $url.');
    if (key.loadFailedCallback != null) key.loadFailedCallback();
    return await ui.instantiateImageCodec(key.fallbackImage ?? emptyImage);
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
        Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
    if (_cacheImagesDirectory.existsSync()) {
      File _cacheImageFile = File(join(_cacheImagesDirectory.path, uId));
      if (_cacheImageFile.existsSync()) {
        return await _cacheImageFile.readAsBytes();
      }
    } else {
      await _cacheImagesDirectory.create();
    }

    Uint8List imageData = await _loadFromRemote(
        key.url, key.header, key.retryLimit, key.retryDuration);
    if (imageData != null) {
      await (File(join(_cacheImagesDirectory.path, uId)))
          .writeAsBytes(imageData);
      return imageData;
    }

    return null;
  }

  /// Fetch the image from network.
  Future<Uint8List> _loadFromRemote(String url, Map<String, String> header,
      int retryLimit, Duration retryDuration) async {
    if (retryLimit < 0) retryLimit = 0;

    /// Retry mechanism.
    Future<http.Response> run<T>(
        Future f(), int retryLimit, Duration retryDuration) async {
      for (int t = 0; t < retryLimit + 1; t++) {
        try {
          http.Response res = await f();
          if (res != null) {
            if (res.statusCode == 200)
              return res;
            else
              debugPrint('Load error, response status code: ' +
                  res.statusCode.toString());
          }
        } catch (_) {}
        await Future.delayed(retryDuration);
      }

      if (retryLimit > 0) debugPrint('Retry failed!');
      return null;
    }

    http.Response _response;
    _response = await run(() async {
      if (header != null)
        return await http.get(url, headers: header).timeout(timeoutDuration);
      else
        return await http.get(url).timeout(timeoutDuration);
    }, retryLimit, retryDuration);
    if (_response != null) return _response.bodyBytes;

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
