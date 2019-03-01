import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, hashValues;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_advanced_networkimage/src/disk_cache.dart';
import 'package:flutter_advanced_networkimage/src/utils.dart' show uid;

typedef Future<Uint8List> ImageProcessing(Uint8List data);

/// Fetches the given URL from the network, associating it with some options.
class AdvancedNetworkImage extends ImageProvider<AdvancedNetworkImage> {
  AdvancedNetworkImage(
    this.url, {
    this.scale: 1.0,
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

  /// Report progress when fetching image.
  ValueChanged<double> loadingProgress;

  /// Extract the real url before fetching.
  final Future<String> getRealUrl;

  /// Receive the data([Uint8List]) and do some manipulations before saving.
  final ImageProcessing preProcessing;

  /// Receive the data([Uint8List]) and do some manipulations after saving.
  final ImageProcessing postProcessing;

  /// If set to enable, the image will skip [ImageCache].
  ///
  /// It is not recommended to disable momery cache, because image provider
  /// will be called a lot of times. If you do not enable [useDiskCache],
  /// image provider will fetch a lot of times. So do not use this option
  /// in production.
  ///
  /// If you want to use the same url with different [fallbackImage],
  /// you should make different [hashCode].
  /// For example, you can set different [retryLimit].
  /// If you enable [useDiskCache], you can set different [differentId]
  /// with the same `Future.value(sameUrl)` in [getRealUrl].
  final bool disableMemoryCache;

  /// Print error.
  final bool printError;

  ImageStream resolve(ImageConfiguration configuration) {
    assert(configuration != null);
    final ImageStream stream = ImageStream();
    AdvancedNetworkImage obtainedKey;
    Future<void> handleError(dynamic exception, StackTrace stack) async {
      await null; // wait an event turn in case a listener has been added to the image stream.
      final _ErrorImageCompleter imageCompleter = _ErrorImageCompleter();
      stream.setCompleter(imageCompleter);
      imageCompleter.setError(
          exception: exception,
          stack: stack,
          context: 'while resolving an image',
          silent: true, // could be a network error or whatnot
          informationCollector: (StringBuffer information) {
            information.writeln('Image provider: $this');
            information.writeln('Image configuration: $configuration');
            if (obtainedKey != null) {
              information.writeln('Image key: $obtainedKey');
            }
          });
    }

    obtainKey(configuration).then<void>((AdvancedNetworkImage key) {
      obtainedKey = key;
      if (key.disableMemoryCache) {
        stream.setCompleter(load(key));
      } else {
        final ImageStreamCompleter completer = PaintingBinding
            .instance.imageCache
            .putIfAbsent(key, () => load(key), onError: handleError);
        if (completer != null) {
          stream.setCompleter(completer);
        }
      }
    }).catchError(handleError);
    return stream;
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

    String uId = uid(key.url);

    if (useDiskCache) {
      try {
        Uint8List _diskCache = await _loadFromDiskCache(key, uId);
        if (_diskCache != null) {
          if (key.postProcessing != null)
            _diskCache = (await key.postProcessing(_diskCache)) ?? _diskCache;
          if (key.loadedCallback != null) key.loadedCallback();
          return await PaintingBinding.instance
              .instantiateImageCodec(_diskCache);
        }
      } catch (e) {
        if (key.printError) debugPrint(e.toString());
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
        return await PaintingBinding.instance.instantiateImageCodec(imageData);
      }
    }

    if (key.loadFailedCallback != null) key.loadFailedCallback();
    if (key.fallbackAssetImage != null) {
      ByteData imageData = await rootBundle.load(key.fallbackAssetImage);
      return await PaintingBinding.instance
          .instantiateImageCodec(imageData.buffer.asUint8List());
    }
    if (key.fallbackImage != null)
      return await PaintingBinding.instance
          .instantiateImageCodec(key.fallbackImage);

    throw Exception('Failed to load $url.');
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final AdvancedNetworkImage typedOther = other;
    return url == typedOther.url &&
        scale == typedOther.scale &&
        header == typedOther.header &&
        useDiskCache == typedOther.useDiskCache &&
        retryLimit == typedOther.retryLimit &&
        retryDurationFactor == typedOther.retryDurationFactor &&
        retryDuration == typedOther.retryDuration;
  }

  @override
  int get hashCode => ui.hashValues(url, scale, header, useDiskCache,
      retryLimit, retryDuration, retryDurationFactor, timeoutDuration);

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
Future<Uint8List> _loadFromDiskCache(
    AdvancedNetworkImage key, String uId) async {
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
    DiskCache diskCache = DiskCache();
    Uint8List data = await diskCache.load(uId);
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

/// Fetch the image from network.
@visibleForTesting
Future<Uint8List> loadFromRemote(
  String url,
  Map<String, String> header,
  int retryLimit,
  Duration retryDuration,
  double retryDurationFactor,
  Duration timeoutDuration,
  ValueChanged<double> progressReport,
  Future<String> getRealUrl, {
  bool printError = false,
}) async {
  assert(url != null);
  assert(retryLimit != null);

  if (retryLimit < 0) retryLimit = 0;

  /// Retry mechanism.
  Future<http.Response> run<T>(Future f(), int retryLimit,
      Duration retryDuration, double retryDurationFactor) async {
    for (int t in List.generate(retryLimit + 1, (int t) => t + 1)) {
      try {
        http.Response res = await f();
        if (res != null && res.bodyBytes.length > 0) {
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

    if (retryLimit > 0 && printError) debugPrint('Retry failed!');
    return null;
  }

  http.Response _response;
  _response = await run(() async {
    String _url = url;
    if (getRealUrl != null) _url = (await getRealUrl) ?? url;

    if (progressReport != null) {
      final _req = http.Request('GET', Uri.parse(_url));
      _req.headers.addAll(header ?? {});
      final _res = await _req.send().timeout(timeoutDuration);
      List<int> buffer = [];
      final Completer<http.Response> completer = Completer<http.Response>();
      StreamSubscription<List<int>> subscription;
      subscription = _res.stream.listen((bytes) {
        try {
          buffer.addAll(bytes);
          double progress = buffer.length / (_res.contentLength ?? 1.0);
          if (_res.contentLength != null) progressReport(progress);
        } catch (e) {
          if (printError) debugPrint(e.toString());
          subscription.cancel();
          completer.complete(http.Response.bytes([], _res.statusCode,
              request: _res.request,
              headers: _res.headers,
              isRedirect: _res.isRedirect,
              persistentConnection: _res.persistentConnection,
              reasonPhrase: _res.reasonPhrase));
        }
      }, onDone: () {
        completer.complete(http.Response.bytes(buffer, _res.statusCode,
            request: _res.request,
            headers: _res.headers,
            isRedirect: _res.isRedirect,
            persistentConnection: _res.persistentConnection,
            reasonPhrase: _res.reasonPhrase));
      });
      return completer.future;
    } else {
      return await http.get(_url, headers: header).timeout(timeoutDuration);
    }
  }, retryLimit, retryDuration, retryDurationFactor);
  if (_response != null) return _response.bodyBytes;

  return null;
}

// A completer used when resolving an image fails sync.
class _ErrorImageCompleter extends ImageStreamCompleter {
  _ErrorImageCompleter();

  void setError({
    String context,
    dynamic exception,
    StackTrace stack,
    InformationCollector informationCollector,
    bool silent = false,
  }) {
    reportError(
      context: context,
      exception: exception,
      stack: stack,
      informationCollector: informationCollector,
      silent: silent,
    );
  }
}
