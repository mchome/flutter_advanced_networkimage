import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart';

typedef Future<Uint8List> _ImageProcessing(Uint8List data);

/// The dart:html implementation of [NetworkImage].
///
/// NetworkImage on the web does not support decoding to a specified size.
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
    this.disableMemoryCache: false,
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
        assert(disableMemoryCache != null),
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
  VoidCallback loadedFromDiskCacheCallback;

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

  /// If set to enable, the image will skip [ImageCache].
  ///
  /// It is not recommended to disable momery cache, because image provider
  /// will be called a lot of times. If you do not enable [useDiskCache],
  /// image provider will fetch a lot of times. So do not use this option
  /// in production.
  ///
  /// If you want to use the same url with different [fallbackImage],
  /// you should make different [==].
  /// For example, you can set different [retryLimit].
  /// If you enable [useDiskCache], you can set different [differentId]
  /// with the same `() => Future.value(sameUrl)` in [getRealUrl].
  final bool disableMemoryCache;

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
  ImageStreamCompleter load(AdvancedNetworkImage key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AdvancedNetworkImage>('Image key', key);
      },
    );
  }

  Future<ui.Codec> _loadAsync(
      AdvancedNetworkImage key, DecoderCallback decode) {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key.url);

    return ui.webOnlyInstantiateImageCodecFromUrl(// ignore: undefined_function
        resolved) as Future<ui.Codec>;
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
