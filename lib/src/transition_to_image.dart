import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_advanced_networkimage/provider.dart';

typedef Widget LoadingWidgetBuilder(double progress);

class TransitionToImage extends StatefulWidget {
  const TransitionToImage({
    Key key,
    @required this.image,
    this.width,
    this.height,
    this.borderRadius,
    this.blendMode,
    this.fit: BoxFit.contain,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.placeholder: const Icon(Icons.clear),
    this.duration: const Duration(milliseconds: 300),
    this.tween,
    this.curve: Curves.easeInOut,
    this.transitionType: TransitionType.fade,
    this.loadingWidget = const Center(child: const CircularProgressIndicator()),
    this.loadingWidgetBuilder,
    this.enableRefresh: false,
    this.disableMemoryCache: false,
    this.disableMemoryCacheIfFailed: false,
    this.loadedCallback,
    this.loadFailedCallback,
    this.forceRebuildWidget: false,
    this.printError = false,
  })  : assert(image != null),
        assert(fit != null),
        assert(alignment != null),
        assert(repeat != null),
        assert(matchTextDirection != null),
        assert(placeholder != null),
        assert(duration != null),
        assert(curve != null),
        assert(transitionType != null),
        assert(loadingWidget != null),
        assert(enableRefresh != null),
        assert(disableMemoryCache != null),
        assert(disableMemoryCacheIfFailed != null),
        assert(forceRebuildWidget != null),
        assert(printError != null),
        super(key: key);

  /// The target image that is displayed.
  final ImageProvider image;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder image does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder image does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double height;

  /// The border radius of the rounded corners.
  ///
  /// Values are clamped so that horizontal and vertical radii sums do not
  /// exceed width/height.
  ///
  /// This value is ignored if [clipper] is non-null.
  final BorderRadius borderRadius;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BlendMode blendMode;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit fit;

  /// How to align the image within its bounds.
  ///
  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, a [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then an ambient [Directionality] widget
  /// must be in scope.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final Alignment alignment;

  /// How to paint any portions of the layout bounds not covered by the image.
  final ImageRepeat repeat;

  /// Whether to paint the image in the direction of the [TextDirection].
  ///
  /// If this is true, then in [TextDirection.ltr] contexts, the image will be
  /// drawn with its origin in the top left (the "normal" painting direction for
  /// images); and in [TextDirection.rtl] contexts, the image will be drawn with
  /// a scaling factor of -1 in the horizontal direction so that the origin is
  /// in the top right.
  ///
  /// This is occasionally used with images in right-to-left environments, for
  /// images that were designed for left-to-right locales. Be careful, when
  /// using this, to not flip images with integral shadows, text, or other
  /// effects that will look incorrect when flipped.
  ///
  /// If this is true, there must be an ambient [Directionality] widget in
  /// scope.
  final bool matchTextDirection;

  /// Widget displayed while the target [image] failed to load.
  final Widget placeholder;

  /// The duration of the fade-out animation for the result.
  final Duration duration;

  /// The tween of the fade-out animation for the result.
  final Tween tween;

  /// The curve of the fade-out animation for the result.
  final Curve curve;

  /// The transition type of the fade-out animation for the result.
  final TransitionType transitionType;

  /// Widget displayed when the target [image] is loading.
  final Widget loadingWidget;

  /// Widget builder (with loading progress) displayed
  /// when the target [image] is loading and loadingWidget is null.
  final LoadingWidgetBuilder loadingWidgetBuilder;

  /// Enable an internal [GestureDetector] for manually refreshing.
  final bool enableRefresh;

  /// If set to enable, the image provider will be evicted from [ImageCache].
  final bool disableMemoryCache;

  /// If set to enable, the image provider will be evicted from [ImageCache]
  /// if the image failed to load.
  final bool disableMemoryCacheIfFailed;

  /// The callback will fire when the image loaded.
  final VoidCallback loadedCallback;

  /// The callback will fire when the image failed to load.
  final VoidCallback loadFailedCallback;

  /// If set to enable, the [loadedCallback] or [loadFailedCallback]
  /// will fire again.
  final bool forceRebuildWidget;

  /// Print error.
  final bool printError;

  @override
  _TransitionToImageState createState() => _TransitionToImageState();
}

enum _TransitionStatus {
  start,
  loading,
  animating,
  completed,
}
enum TransitionType {
  slide,
  fade,
}

class _TransitionToImageState extends State<TransitionToImage>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation _animation;
  Tween<double> _fadeTween = Tween(begin: 0.0, end: 1.0);
  Tween<Offset> _slideTween =
      Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);

  ImageStream _imageStream;
  ImageInfo _imageInfo;
  bool _loadFailed = false;
  double _progress = 0.0;

  _TransitionStatus _status = _TransitionStatus.start;

  ImageProvider get _imageProvider => widget.image;

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() => setState(() {}));
    if (widget.transitionType == TransitionType.fade) {
      _fadeTween = widget.tween ?? Tween(begin: 0.0, end: 1.0);
    } else if (widget.transitionType == TransitionType.slide) {
      _slideTween = widget.tween ??
          Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);
    }
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _getImage();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(TransitionToImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.image != oldWidget.image) || widget.forceRebuildWidget)
      _getImage();
  }

  @override
  void reassemble() {
    _getImage();
    super.reassemble();
  }

  @override
  void dispose() {
    _imageStream.removeListener(_updateImage);
    _controller.dispose();
    super.dispose();
  }

  void _resolveStatus() {
    setState(() {
      switch (_status) {
        case _TransitionStatus.start:
          if (_imageInfo == null) {
            _status = _TransitionStatus.loading;
          } else {
            _status = _TransitionStatus.completed;
            _controller.forward(from: 1.0);
          }
          break;
        case _TransitionStatus.loading:
          if (_imageInfo != null) {
            _status = _TransitionStatus.animating;
            _controller.forward(from: 0.0);
          }
          break;
        case _TransitionStatus.animating:
          if (_controller.status == AnimationStatus.completed)
            _status = _TransitionStatus.completed;
          break;
        case _TransitionStatus.completed:
          break;
      }
    });
  }

  void _getImage({bool reload: false}) {
    if (reload) {
      if (widget.printError) debugPrint('Reloading image.');
      _imageProvider.evict();
    }

    final ImageStream oldImageStream = _imageStream;
    if (_imageProvider is AdvancedNetworkImage) {
      var callback = (_imageProvider as AdvancedNetworkImage).loadingProgress;
      (_imageProvider as AdvancedNetworkImage).loadingProgress =
          (double progress) {
        if (mounted)
          setState(() => _progress = progress);
        else
          return oldImageStream?.removeListener(_updateImage);
        if (callback != null) callback(progress);
      };
    }
    _imageStream = _imageProvider.resolve(createLocalImageConfiguration(
      context,
      size: widget.width != null && widget.height != null
          ? Size(widget.width, widget.height)
          : null,
    ));
    if (_imageInfo != null &&
        !reload &&
        (_imageStream.key == oldImageStream?.key)) {
      if (widget.forceRebuildWidget) {
        if (widget.loadedCallback != null)
          widget.loadedCallback();
        else if (widget.loadFailedCallback != null) widget.loadFailedCallback();
      }
      setState(() => _status = _TransitionStatus.completed);
    } else {
      setState(() {
        _status = _TransitionStatus.start;
        _loadFailed = false;
      });
      oldImageStream?.removeListener(_updateImage);
      _imageStream.addListener(_updateImage, onError: _catchBadImage);
      _resolveStatus();
    }
  }

  void _updateImage(ImageInfo info, bool synchronousCall) {
    _imageInfo = info;
    if (_imageInfo != null) {
      _resolveStatus();
      if (widget.loadedCallback != null) widget.loadedCallback();
      if (widget.disableMemoryCache) _imageProvider.evict();
    }
  }

  void _catchBadImage(dynamic exception, StackTrace stackTrace) {
    if (widget.printError) debugPrint(exception.toString());
    setState(() => _loadFailed = true);
    _resolveStatus();
    if (widget.loadFailedCallback != null) widget.loadFailedCallback();
    if (widget.disableMemoryCache || widget.disableMemoryCacheIfFailed)
      _imageProvider.evict();
  }

  @override
  Widget build(BuildContext context) {
    return _loadFailed
        ? widget.enableRefresh
            ? GestureDetector(
                onTap: () => _getImage(reload: true),
                child: widget.placeholder,
              )
            : widget.placeholder
        : _status == _TransitionStatus.start ||
                _status == _TransitionStatus.loading
            ? widget.loadingWidgetBuilder != null
                ? widget.loadingWidgetBuilder(_progress)
                : widget.loadingWidget
            : widget.transitionType == TransitionType.fade
                ? FadeTransition(
                    opacity: _fadeTween.animate(_animation),
                    child: widget.borderRadius != null
                        ? ClipRRect(
                            borderRadius: widget.borderRadius,
                            child: buildRawImage(),
                          )
                        : buildRawImage(),
                  )
                : SlideTransition(
                    position: _slideTween.animate(_animation),
                    child: widget.borderRadius != null
                        ? ClipRRect(
                            borderRadius: widget.borderRadius,
                            child: buildRawImage(),
                          )
                        : buildRawImage(),
                  );
  }

  RawImage buildRawImage() {
    return RawImage(
      image: _imageInfo?.image,
      width: widget.width,
      height: widget.height,
      scale: _imageInfo?.scale ?? 1.0,
      colorBlendMode: widget.blendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      matchTextDirection: widget.matchTextDirection,
    );
  }
}
