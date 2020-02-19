import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show hashValues;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart';

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
    this.skipRetryStatusCode,
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
  final UrlResolver getRealUrl;

  /// Print error messages.
  final bool printError;

  /// The [HttpStatus] code that you can skip retrying if you meet them.
  final List<int> skipRetryStatusCode;

  @override
  Future<AdvancedNetworkSvg> obtainKey(PictureConfiguration picture) {
    return SynchronousFuture<AdvancedNetworkSvg>(this);
  }

  @override
  PictureStreamCompleter load(AdvancedNetworkSvg key,
      {PictureErrorListener onError}) {
    return OneFramePictureStreamCompleter(
      _loadAsync(key, onError: onError),
      informationCollector: () sync* {
        yield DiagnosticsProperty<PictureProvider>('Picture provider', this);
        yield DiagnosticsProperty<AdvancedNetworkSvg>('Picture key', key);
      },
    );
  }

  Future<bool> evict({bool disk = false}) async {
    assert(disk != null);

    if (disk) {
      return removeFromCache(url);
    }
    return false;
  }

  Future<PictureInfo> _loadAsync(AdvancedNetworkSvg key,
      {PictureErrorListener onError}) async {
    assert(key == this);

    if (useDiskCache) {
      try {
        Uint8List _diskCache = await loadFromDiskCache();
        if (key.loadedCallback != null) key.loadedCallback();
        return await decode(_diskCache, key.colorFilter, key.toString(),
            onError: onError);
      } catch (e) {
        if (key.printError) print(e);
      }
    }

    Uint8List imageData = await loadFromRemote(
      key.url,
      key.header,
      key.retryLimit,
      key.retryDuration,
      key.retryDurationFactor,
      key.timeoutDuration,
      null,
      key.getRealUrl,
      printError: key.printError,
    );
    if (imageData != null) {
      if (key.loadedCallback != null) key.loadedCallback();
      return await decode(imageData, key.colorFilter, key.toString(),
          onError: onError);
    }

    if (key.loadFailedCallback != null) key.loadFailedCallback();
    if (key.fallbackAssetImage != null) {
      ByteData imageData = await rootBundle.load(key.fallbackAssetImage);
      return await decode(
          imageData.buffer.asUint8List(), key.colorFilter, key.toString(),
          onError: onError);
    }
    if (key.fallbackImage != null)
      return await decode(key.fallbackImage, key.colorFilter, key.toString(),
          onError: onError);

    return Future.error(StateError('Failed to load $url.'));
  }

  Future<PictureInfo> decode(
      Uint8List imageData, ColorFilter colorFilter, String keyString,
      {PictureErrorListener onError}) {
    if (onError != null)
      return decoder(imageData, colorFilter, keyString)..catchError(onError);
    return decoder(imageData, colorFilter, keyString);
  }

  /// Load the disk cache
  ///
  /// Check the following conditions: (no [CacheRule])
  /// 1. Check if cache directory exist. If not exist, create it.
  /// 2. Check if cached file(uid) exist. If yes, load the cache,
  ///   otherwise go to download step.
  Future<Uint8List> loadFromDiskCache() async {
    AdvancedNetworkSvg key = this;

    String uId = uid(key.url);

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

      Uint8List imageData = await loadFromRemote(
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.retryDurationFactor,
        key.timeoutDuration,
        null,
        key.getRealUrl,
        skipRetryStatusCode: key.skipRetryStatusCode,
        printError: key.printError,
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

      data = await loadFromRemote(
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.retryDurationFactor,
        key.timeoutDuration,
        null,
        key.getRealUrl,
        printError: key.printError,
      );
      if (data != null) {
        await diskCache.save(uId, data, key.cacheRule);
        return data;
      }
    }

    return null;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkSvg typedOther = other;
    return url == typedOther.url &&
        scale == typedOther.scale &&
        useDiskCache == typedOther.useDiskCache &&
        retryLimit == typedOther.retryLimit &&
        retryDurationFactor == typedOther.retryDurationFactor &&
        retryDuration == typedOther.retryDuration;
  }

  @override
  int get hashCode => ui.hashValues(url, scale, useDiskCache, retryLimit,
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
