import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, hashValues;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart';

typedef Future<Uint8List> _ImageProcessing(Uint8List data);

/// Fetches the given URL from the network, associating it with some options.
class AdvancedNetworkImage extends ImageProvider<AdvancedNetworkImage> {
  AdvancedNetworkImage(
    this.url, {
    this.scale: 1.0,
    this.width,
    this.height,
    this.header,
    this.useDiskCache: false,
    this.retryLimit: 5,
    this.retryDuration: const Duration(milliseconds: 500),
    this.retryDurationFactor: 1.5,
    this.timeoutDuration: const Duration(seconds: 5),
    this.loadedCallback,
    this.loadFailedCallback,
    this.loadedFromDiskCacheCallback,
    this.fallbackAssetImage,
    this.fallbackImage,
    this.cacheRule,
    this.loadingProgress,
    this.getRealUrl,
    this.preProcessing,
    this.postProcessing,
    this.printError = false,
    this.skipRetryStatusCode,
    this.id,
  })  : assert(url != null),
        assert(scale != null),
        assert(useDiskCache != null),
        assert(retryLimit != null),
        assert(retryDuration != null),
        assert(retryDurationFactor != null),
        assert(timeoutDuration != null),
        assert(printError != null);

  /// The URL from which the image will be fetched.
  final String url;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The width the image should decode to and cache in memory.
  final int width;

  /// The height the image should decode to and cache in momory.
  final int height;

  /// The HTTP headers that will be used with [http] to fetch image from network.
  final Map<String, String> header;

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

  /// The callback will fire when the image loaded.
  final VoidCallback loadedCallback;

  /// The callback will fire when the image failed to load.
  final VoidCallback loadFailedCallback;

  /// The callback will fire when the image loaded from DiskCache.
  final VoidCallback loadedFromDiskCacheCallback;

  /// Displays image from an asset bundle when the image failed to load.
  final String fallbackAssetImage;

  /// The image will be displayed when the image failed to load
  /// and [fallbackAssetImage] is null.
  final Uint8List fallbackImage;

  /// Disk cache rules for advanced control.
  final CacheRule cacheRule;

  /// Report loading progress and data when fetching image.
  LoadingProgress loadingProgress;

  /// Extract the real url before fetching.
  final UrlResolver getRealUrl;

  /// Receive the data([Uint8List]) and do some manipulations before saving.
  final _ImageProcessing preProcessing;

  /// Receive the data([Uint8List]) and do some manipulations after saving.
  final _ImageProcessing postProcessing;

  /// Print error messages.
  final bool printError;

  /// The [HttpStatus] code that you can skip retrying if you meet them.
  final List<int> skipRetryStatusCode;

  final String id;

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  Future<bool> evict({
    ImageCache cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
    bool memory = true,
    bool disk = false,
  }) async {
    assert(memory != null);
    assert(disk != null);

    if (memory) {
      cache ??= imageCache;
      final key = await obtainKey(configuration);
      return cache.evict(key);
    }
    if (disk) {
      return removeFromCache(url);
    }
    return false;
  }

  @override
  ImageStreamCompleter load(AdvancedNetworkImage key, DecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode, chunkEvents),
      // chunkEvents: chunkEvents.stream, // TODO
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AdvancedNetworkImage>('Image key', key);
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    AdvancedNetworkImage key,
    DecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    assert(key == this);

    if (useDiskCache) {
      try {
        Uint8List _diskCache = await loadFromDiskCache();
        if (_diskCache != null) {
          if (key.postProcessing != null)
            _diskCache = (await key.postProcessing(_diskCache)) ?? _diskCache;
          if (key.loadedCallback != null) key.loadedCallback();
          return decode(
            _diskCache,
            cacheWidth: key.width,
            cacheHeight: key.height,
          );
        }
      } catch (e) {
        if (key.printError) print(e);
      }
    } else {
      Uint8List imageData = await loadFromRemote(
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.retryDurationFactor,
        key.timeoutDuration,
        key.loadingProgress,
        key.getRealUrl,
        printError: key.printError,
      );
      if (imageData != null) {
        if (key.postProcessing != null)
          imageData = (await key.postProcessing(imageData)) ?? imageData;
        if (key.loadedCallback != null) key.loadedCallback();
        return decode(
          imageData,
          cacheWidth: key.width,
          cacheHeight: key.height,
        );
      }
    }

    if (key.loadFailedCallback != null) key.loadFailedCallback();
    if (key.fallbackAssetImage != null) {
      ByteData imageData = await rootBundle.load(key.fallbackAssetImage);
      return decode(
        imageData.buffer.asUint8List(),
        cacheWidth: key.width,
        cacheHeight: key.height,
      );
    }
    if (key.fallbackImage != null)
      return decode(
        key.fallbackImage,
        cacheWidth: key.width,
        cacheHeight: key.height,
      );

    return Future.error(StateError('Failed to load $url.'));
  }

  /// Load the disk cache
  ///
  /// Check the following conditions: (no [CacheRule])
  /// 1. Check if cache directory exist. If not exist, create it.
  /// 2. Check if cached file(uid) exist. If yes, load the cache,
  ///   otherwise go to download step.
  Future<Uint8List> loadFromDiskCache() async {
    AdvancedNetworkImage key = this;

    String uId = uid(key.url);

    if (key.cacheRule == null) {
      Directory _cacheImagesDirectory =
          Directory(join((await getTemporaryDirectory()).path, 'imagecache'));
      if (_cacheImagesDirectory.existsSync()) {
        File _cacheImageFile = File(join(_cacheImagesDirectory.path, uId));
        if (_cacheImageFile.existsSync()) {
          if (key.loadedFromDiskCacheCallback != null)
            key.loadedFromDiskCacheCallback();
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
        key.loadingProgress,
        key.getRealUrl,
        skipRetryStatusCode: key.skipRetryStatusCode,
        printError: key.printError,
      );
      if (imageData != null) {
        if (key.preProcessing != null)
          imageData = (await key.preProcessing(imageData)) ?? imageData;
        await (File(join(_cacheImagesDirectory.path, uId)))
            .writeAsBytes(imageData);
        return imageData;
      }
    } else {
      DiskCache diskCache = DiskCache()..printError = key.printError;
      Uint8List data = await diskCache.load(uId, rule: key.cacheRule);
      if (data != null) {
        if (key.loadedFromDiskCacheCallback != null)
          key.loadedFromDiskCacheCallback();
        return data;
      }

      data = await loadFromRemote(
        key.url,
        key.header,
        key.retryLimit,
        key.retryDuration,
        key.retryDurationFactor,
        key.timeoutDuration,
        key.loadingProgress,
        key.getRealUrl,
        printError: key.printError,
      );
      if (data != null) {
        if (key.preProcessing != null)
          data = (await key.preProcessing(data)) ?? data;
        await diskCache.save(uId, data, key.cacheRule);
        return data;
      }
    }

    return null;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkImage typedOther = other;
    return id == null
        ? url == typedOther.url && scale == typedOther.scale
        : id == typedOther.id;
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
