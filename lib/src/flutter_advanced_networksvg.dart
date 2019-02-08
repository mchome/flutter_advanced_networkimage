import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show hashValues;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart' show uid;

/// Fetches the given URL from the network, associating it with some options.
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
    this.fallbackAssetImage,
    this.fallbackImage,
    this.cacheRule,
    this.getRealUrl,
    this.printError = false,
  })  : assert(url != null),
        assert(scale != null),
        assert(useDiskCache != null),
        assert(retryLimit != null),
        assert(retryDuration != null),
        assert(printError != null);

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

  /// Displays image from an asset bundle when the image failed to load.
  final String fallbackAssetImage;

  /// The image will be displayed when the image failed to load
  /// and [fallbackAssetImage] is null.
  final Uint8List fallbackImage;

  /// Disk cache rules for advanced control.
  final CacheRule cacheRule;

  /// Extract the real url before fetching.
  final Future<String> getRealUrl;

  /// Print error.
  final bool printError;

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

    if (useDiskCache) {
      try {
        Uint8List _diskCache = await _loadFromDiskCache(key, uId);
        if (key.loadedCallback != null) key.loadedCallback();
        return await decoder(_diskCache, key.colorFilter, key.toString());
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    Uint8List imageData = await _loadFromRemote(
      key.url,
      key.header,
      key.retryLimit,
      key.retryDuration,
      key.retryDurationFactor,
      key.timeoutDuration,
      key.getRealUrl,
      printError: key.printError,
    );
    if (imageData != null) {
      if (key.loadedCallback != null) key.loadedCallback();
      return await decoder(imageData, key.colorFilter, key.toString());
    }

    if (key.loadFailedCallback != null) key.loadFailedCallback();
    if (key.fallbackAssetImage != null) {
      ByteData imageData = await rootBundle.load(key.fallbackAssetImage);
      return await decoder(
          imageData.buffer.asUint8List(), key.colorFilter, key.toString());
    }
    if (key.fallbackImage != null)
      return await decoder(key.fallbackImage, key.colorFilter, key.toString());

    throw Exception('Failed to load $url.');
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

/// Load the disk cache
///
/// Check the following conditions: (no [CacheRule])
/// 1. Check if cache directory exist. If not exist, create it.
/// 2. Check if cached file(uid) exist. If yes, load the cache,
///   otherwise go to download step.
Future<Uint8List> _loadFromDiskCache(AdvancedNetworkSvg key, String uId) async {
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
      key.retryDurationFactor,
      key.timeoutDuration,
      key.getRealUrl,
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
      key.retryDurationFactor,
      key.timeoutDuration,
      key.getRealUrl,
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
  double retryDurationFactor,
  Duration timeoutDuration,
  Future<String> getRealUrl, {
  bool printError = false,
}) async {
  if (retryLimit < 0) retryLimit = 0;

  /// Retry mechanism.
  Future<http.Response> run<T>(Future f(), int retryLimit,
      Duration retryDuration, double retryDurationFactor) async {
    for (int t in List.generate(retryLimit + 1, (int t) => t + 1)) {
      try {
        http.Response res = await f();
        if (res != null) {
          if (res.statusCode == HttpStatus.ok)
            return res;
          else if (printError)
            debugPrint('Load error, response status code: ' +
                res.statusCode.toString());
        }
      } catch (e) {
        if (printError) debugPrint(e.toString());
      }
      await Future.delayed(retryDuration * pow(retryDurationFactor, t - 1));
    }

    if (retryLimit > 0) debugPrint('Retry failed!');
    return null;
  }

  http.Response _response;
  _response = await run(() async {
    String _url = url;
    if (getRealUrl != null) _url = await getRealUrl;

    return await http.get(_url, headers: header).timeout(timeoutDuration);
  }, retryLimit, retryDuration, retryDurationFactor);
  if (_response != null) return _response.bodyBytes;

  return null;
}
