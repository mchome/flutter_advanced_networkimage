library transition_to_image;

import 'dart:typed_data';
import 'dart:ui';

import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/utils.dart';

class TransitionToImage extends StatefulWidget {
  const TransitionToImage(
    this.image, {
    Key key,
    this.placeholder: const Icon(Icons.clear),
    this.duration: const Duration(milliseconds: 300),
    this.tween,
    this.curve: Curves.easeInOut,
    this.transitionType: TransitionType.fade,
    this.width,
    this.height,
    this.blendMode,
    this.fit: BoxFit.contain,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.loadingWidget = const CircularProgressIndicator(),
    this.enableRefresh: true,
  })  : assert(image != null),
        assert(placeholder != null),
        assert(duration != null),
        assert(curve != null),
        assert(transitionType != null),
        assert(loadingWidget != null),
        assert(fit != null),
        assert(alignment != null),
        assert(repeat != null),
        assert(matchTextDirection != null),
        super(key: key);

  /// The target image that is displayed.
  final ImageProvider image;

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

  /// Widget displayed while the target [image] is loading.
  final Widget loadingWidget;

  /// Enable a interior  [GestureDetector] for manually refreshing.
  final bool enableRefresh;

  reloadImage() {
    _reloadListeners.forEach((listener) {
      if (listener.keys.first == image.hashCode.toString()) {
        (listener.values.first)();
      }
    });
  }

  @override
  _TransitionToImageState createState() => _TransitionToImageState();
}

enum _TransitionStatus {
  loading,
  animating,
  completed,
}
enum TransitionType {
  slide,
  fade,
}

class _TransitionToImageState extends State<TransitionToImage>
    with TickerProviderStateMixin {
  AnimationController _controller;
  Animation _animation;
  Tween<double> _fadeTween = Tween(begin: 0.0, end: 1.0);
  Tween<Offset> _slideTween =
      Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);

  ImageStream _imageStream;
  ImageInfo _imageInfo;
  bool _loadFailed = false;

  _TransitionStatus _status = _TransitionStatus.loading;

  ImageProvider get _imageProvider => widget.image;

  @override
  initState() {
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() => setState(() {}));
    if (widget.transitionType == TransitionType.fade) {
      _fadeTween = widget.tween ?? Tween(begin: 0.0, end: 1.0);
    } else if (widget.transitionType == TransitionType.slide) {
      _slideTween = widget.tween ??
          Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);
    }
    _reloadListeners.removeWhere((listener) =>
        listener.keys.first == _imageProvider.hashCode.toString());
    _reloadListeners.add(
        {_imageProvider.hashCode.toString(): () => _getImage(reload: true)});
    super.initState();
  }

  @override
  didChangeDependencies() {
    _getImage();
    super.didChangeDependencies();
  }

  @override
  didUpdateWidget(TransitionToImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _getImage();
  }

  @override
  dispose() {
    _imageStream.removeListener(_updateImage);
    _controller.dispose();
    _reloadListeners.removeWhere((listener) =>
        listener.keys.first == _imageProvider.hashCode.toString());
    super.dispose();
  }

  _resolveStatus() {
    try {
      setState(() {});
    } catch (_) {
      _imageStream?.removeListener(_updateImage);
      return;
    }
    setState(() {
      switch (_status) {
        case _TransitionStatus.loading:
          if (_imageInfo != null) {
            _controller.duration = widget.duration;
            _animation = CurvedAnimation(
              parent: _controller,
              curve: widget.curve,
            );
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

  _getImage({bool reload: false}) {
    final ImageStream oldImageStream = _imageStream;
    _imageStream =
        _imageProvider.resolve(createLocalImageConfiguration(context));
    if (_imageInfo != null &&
        !reload &&
        (_imageStream.key == oldImageStream?.key)) {
      setState(() => _status = _TransitionStatus.completed);
    } else {
      if (reload) {
        debugPrint('Reloading image.');
        _imageProvider.evict();
        _imageStream =
            _imageProvider.resolve(createLocalImageConfiguration(context));
      }
      setState(() {
        _status = _TransitionStatus.loading;
        _loadFailed = false;
      });
      oldImageStream?.removeListener(_updateImage);
      _imageStream.addListener(_updateImage);
    }
  }

  _updateImage(ImageInfo info, bool synchronousCall) {
    _imageInfo = info;
    if (_imageInfo != null) {
      _imageInfo.image
          .toByteData(format: ImageByteFormat.png)
          .then((ByteData data) {
        if (ListEquality().equals(data.buffer.asUint8List(), emptyImage) ||
            ListEquality().equals(data.buffer.asUint8List(), emptyImage2)) {
          setState(() => _loadFailed = true);
        }
      });
      _resolveStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Color(0),
      child: (_loadFailed)
          ? (widget.enableRefresh)
              ? GestureDetector(
                  onTap: () => _getImage(reload: true),
                  child: Center(child: widget.placeholder),
                )
              : Center(child: widget.placeholder)
          : (_status == _TransitionStatus.loading)
              ? Center(child: widget.loadingWidget)
              : (widget.transitionType == TransitionType.fade)
                  ? FadeTransition(
                      opacity: _fadeTween.animate(_animation),
                      child: _child(),
                    )
                  : SlideTransition(
                      position: _slideTween.animate(_animation),
                      child: _child(),
                    ),
    );
  }

  Widget _child() {
    return RawImage(
      image: _imageInfo.image,
      width: widget.width,
      height: widget.height,
      colorBlendMode: widget.blendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      matchTextDirection: widget.matchTextDirection,
    );
  }
}

/// Store reload listeners
List<Map<String, Function>> _reloadListeners = List<Map<String, Function>>();
