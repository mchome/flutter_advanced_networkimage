import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show hashValues;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart' show uid;

class AdvancedNetworkSvg extends PictureProvider<AdvancedNetworkSvg> {
  const AdvancedNetworkSvg(
    this.url,
    this.decoder, {
    this.scale: 1.0,
    this.header,
    this.colorFilter,
    this.useDiskCache: false,
    this.retryLimit: 5,
    this.retryDuration: const Duration(milliseconds: 500),
    this.retryDurationFactor: 1.5,
    this.timeoutDuration: const Duration(seconds: 5),
    this.loadedCallback,
    this.loadFailedCallback,
    this.fallbackImage,
    this.cacheRule,
    this.loadingProgress,
  })  : assert(url != null),
        assert(scale != null),
        assert(useDiskCache != null),
        assert(retryLimit != null),
        assert(retryDuration != null);

  /// The URL from which the image will be fetched.
  final String url;

  /// The decoder provided by flutter_svg (svgByteDecoder or svgByteDecoderOutsideViewBox)
  final PictureInfoDecoder<Uint8List> decoder;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The HTTP headers that will be used with [http] to fetch image from network.
  final Map<String, String> header;

  /// The [ColorFilter], if any, to apply to the drawing.
  final ColorFilter colorFilter;

  /// The flag control the disk cache will be used or not.
  final bool useDiskCache;

  /// The retry limit will be used to limit the retry attempts.
  final int retryLimit;

  /// The retry duration will give the interval between the retries.
  final Duration retryDuration;

  /// Apply factor to control retry duration between retry.
  final double retryDurationFactor;

  /// The timeout duration will give the timeout to a fetching function.
  final Duration timeoutDuration;

  /// The callback will be executed when the image loaded.
  final Function loadedCallback;

  /// The callback will be executed when the image failed to load.
  final Function loadFailedCallback;

  /// The image will be displayed when the image failed to load.
  final Uint8List fallbackImage;

  /// Disk cache rules for advanced control.
  final CacheRule cacheRule;

  /// Report progress when fetching image.
  final ValueChanged<double> loadingProgress;

  @override
  Future<AdvancedNetworkSvg> obtainKey() {
    return SynchronousFuture<AdvancedNetworkSvg>(this);
  }

  @override
  PictureStreamCompleter load(AdvancedNetworkSvg key) {
    return OneFramePictureStreamCompleter(
      _loadAsync(key),
      informationCollector: (StringBuffer information) {
        information.writeln('Svg provider: $this');
        information.write('Svg provider: $key');
      },
    );
  }

  Future<PictureInfo> _loadAsync(AdvancedNetworkSvg key) async {
    assert(key == this);

    String uId = uid(key.url);

    try {
      if (useDiskCache) {
        Uint8List _diskCache = await _loadFromDiskCache(key, uId);
        if (key.loadedCallback != null) key.loadedCallback();
        return await decoder(_diskCache, key.colorFilter, key.toString());
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    Uint8List imageData = await _loadFromRemote(
      key.url,
      key.header,
      key.retryLimit,
      key.retryDuration,
      key.loadingProgress,
    );
    if (imageData != null) {
      if (key.loadedCallback != null) key.loadedCallback();
      try {
        return await decoder(imageData, key.colorFilter, key.toString());
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    if (key.loadFailedCallback != null) key.loadFailedCallback();
    if (key.fallbackImage != null)
      return await decoder(key.fallbackImage, key.colorFilter, key.toString());

    throw Exception('Failed to load $url.');
  }

  /// __Load the disk cache__
  ///
  /// Check the following conditions: (no [CacheRule])
  /// 1. Check if cache directory exist. If not exist, create it.
  /// 2. Check if cached file(uid) exist. If yes, load the cache,
  ///   otherwise go to download step.
  Future<Uint8List> _loadFromDiskCache(
      AdvancedNetworkSvg key, String uId) async {
    if (key.cacheRule == null) {
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
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.loadingProgress,
      );
      if (imageData != null) {
        await (File(join(_cacheImagesDirectory.path, uId)))
            .writeAsBytes(imageData);
        return imageData;
      }
    } else {
      DiskCache diskCache = DiskCache();
      Uint8List data = await diskCache.load(uId);
      if (data != null) return data;

      data = await _loadFromRemote(
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.loadingProgress,
      );
      if (data != null) {
        await diskCache.save(uId, data, key.cacheRule);
        return data;
      }
    }

    return null;
  }

  /// Fetch the image from network.
  Future<Uint8List> _loadFromRemote(
    String url,
    Map<String, String> header,
    int retryLimit,
    Duration retryDuration,
    ValueChanged<double> progressReporter,
  ) async {
    if (retryLimit < 0) retryLimit = 0;

    /// Retry mechanism.
    Future<http.Response> run<T>(
        Future f(), int retryLimit, Duration retryDuration) async {
      for (int t = 0; t < retryLimit + 1; t++) {
        try {
          http.Response res = await f();
          if (res != null) {
            if (res.statusCode == HttpStatus.ok)
              return res;
            else
              debugPrint('Load error, response status code: ' +
                  res.statusCode.toString());
          }
        } catch (_) {}
        await Future.delayed(retryDuration * pow(retryDurationFactor, t - 1));
      }

      if (retryLimit > 0) debugPrint('Retry failed!');
      return null;
    }

    http.Response _response;
    _response = await run(() async {
      final _req = http.Request('GET', Uri.parse(url));
      _req.headers.addAll(header ?? {});
      final _res = await _req.send().timeout(timeoutDuration);
      List<int> buffer = [];
      final Completer<http.Response> completer = Completer<http.Response>();
      _res.stream.listen((bytes) {
        buffer.addAll(bytes);
        double progress = buffer.length / _res.contentLength;
        if (progressReporter != null) progressReporter(progress);
        if (progress >= 1.0)
          completer.complete(http.Response.bytes(buffer, _res.statusCode,
              request: _res.request,
              headers: _res.headers,
              isRedirect: _res.isRedirect,
              persistentConnection: _res.persistentConnection,
              reasonPhrase: _res.reasonPhrase));
      });
      return completer.future;
    }, retryLimit, retryDuration);
    if (_response != null) return _response.bodyBytes;

    return null;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkSvg typedOther = other;
    return url == typedOther.url &&
        scale == typedOther.scale &&
        header == typedOther.header &&
        useDiskCache == typedOther.useDiskCache &&
        retryLimit == typedOther.retryLimit &&
        retryDurationFactor == typedOther.retryDurationFactor &&
        retryDuration == typedOther.retryDuration;
  }

  @override
  int get hashCode => hashValues(url, scale, header, useDiskCache, retryLimit,
      retryDuration, retryDurationFactor, timeoutDuration);

  @override
  String toString() => '$runtimeType('
      '"$url",'
      'scale: $scale,'
      'header: $header,'
      'useDiskCache: $useDiskCache,'
      'retryLimit: $retryLimit,'
      'retryDuration: $retryDuration,'
      'retryDurationFactor: $retryDurationFactor,'
      'timeoutDuration: $timeoutDuration'
      ')';
}
