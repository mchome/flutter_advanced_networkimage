library transition_to_image;

import 'package:flutter/material.dart';

class TransitionToImage extends StatefulWidget {
  const TransitionToImage(
    this.image, {
    Key key,
    this.placeholder: const CircularProgressIndicator(),
    this.duration: const Duration(milliseconds: 300),
    this.tween,
    this.curve: Curves.easeInOut,
    this.transitionType: TransitionType.fade,
    this.useReload: false,
    this.reloadWidget,
    this.fallbackWidget,
  })  : assert(image != null),
        assert(placeholder != null),
        assert(duration != null),
        assert(curve != null),
        assert(transitionType != null),
        super(key: key);

  final ImageProvider image;
  final Widget placeholder;
  final Duration duration;
  final Tween tween;
  final Curve curve;
  final TransitionType transitionType;
  final bool useReload;
  final Widget reloadWidget;
  final Widget fallbackWidget;

  reloadImage() {
    imageCache.clear();
    _reloadListeners.forEach((listener) {
      if (listener.keys.first == image.hashCode.toString()) {
        (listener.values.first)();
      }
    });
  }

  @override
  _TransitionToImageState createState() => new _TransitionToImageState();
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
  Tween<double> _fadeTween;
  Tween<Offset> _slideTween;

  ImageStream _imageStream;
  ImageInfo _imageInfo;
  bool _loadFailed = false;

  _TransitionStatus _status = _TransitionStatus.loading;

  ImageProvider get _imageProvider => widget.image;

  @override
  initState() {
    _controller =
        new AnimationController(vsync: this, duration: widget.duration)
          ..addListener(() => setState(() {}));
    _fadeTween = widget.tween;
    _slideTween = widget.tween;
    if (_fadeTween == null) _fadeTween = new Tween(begin: 0.0, end: 1.0);
    if (_slideTween == null)
      _slideTween = new Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);
    _reloadListeners.forEach((listener) {
      if (listener.keys.first == _imageProvider.hashCode.toString()) {
        _reloadListeners.remove(listener);
      }
    });
    _reloadListeners.add({
      _imageProvider.hashCode.toString(): () {
        if (_loadFailed) {
          print('Reloading image.');
          _getImage();
        }
      }
    });
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
    _reloadListeners.forEach((listener) {
      if (listener.keys.first == _imageProvider.hashCode.toString()) {
        _reloadListeners.remove(listener);
      }
    });
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
            _animation = new CurvedAnimation(
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

  _getImage() {
    setState(() {
      _loadFailed = false;
    });
    final ImageStream oldImageStream = _imageStream;
    _status = _TransitionStatus.loading;
    _imageStream =
        _imageProvider.resolve(createLocalImageConfiguration(context));
    if (_imageStream.key != oldImageStream?.key) {
      oldImageStream?.removeListener(_updateImage);
      _imageStream.addListener(_updateImage);
    }
  }

  _updateImage(ImageInfo info, bool synchronousCall) {
    _imageInfo = info;
    if (_imageInfo.image.toString() == '[1×1]') {
      setState(() {
        _loadFailed = true;
      });
    }
    _resolveStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      if (widget.useReload) {
        return widget.reloadWidget ?? new Icon(Icons.replay);
      } else if (widget.fallbackWidget != null) {
        return widget.fallbackWidget;
      }
    }

    return (_status == _TransitionStatus.loading)
        ? new Center(child: new CircularProgressIndicator())
        : (widget.transitionType == TransitionType.fade)
            ? new FadeTransition(
                opacity: _fadeTween.animate(_animation),
                child: new RawImage(
                  image: _imageInfo.image,
                ))
            : new SlideTransition(
                position: _slideTween.animate(_animation),
                child: new RawImage(
                  image: _imageInfo.image,
                ));
  }
}

List<Map<String, Function>> _reloadListeners =
    new List<Map<String, Function>>();
