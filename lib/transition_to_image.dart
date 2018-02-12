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
    this.animationType: TransitionType.fade,
  })
      : assert(image != null),
        assert(placeholder != null),
        assert(duration != null),
        assert(curve != null),
        assert(animationType != null),
        super(key: key);

  final ImageProvider image;
  final Widget placeholder;
  final Duration duration;
  final Tween tween;
  final Curve curve;
  final TransitionType animationType;

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
  Tween _tween;

  ImageStream _imageStream;
  ImageInfo _imageInfo;

  _TransitionStatus _status = _TransitionStatus.loading;

  ImageProvider get _imageProvider => widget.image;

  @override
  initState() {
    _controller =
        new AnimationController(vsync: this, duration: widget.duration)
          ..addListener(() => setState(() {}));
    _tween = widget.tween;
    if (_tween == null) _tween = new Tween(begin: 0.0, end: 1.0);
    super.initState();
  }

  @override
  didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  reassemble() {
    _resolveImage();
    super.reassemble();
  }

  @override
  dispose() {
    _imageStream?.removeListener(_handleImageLoaded);
    _controller.dispose();
    super.dispose();
  }

  _resolveStatus() {
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

  _resolveImage() {
    _imageStream =
        _imageProvider.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    _imageInfo = info;
    _resolveStatus();
  }

  @override
  Widget build(BuildContext context) {
    return (_status == _TransitionStatus.loading)
        ? new Center(child: new CircularProgressIndicator())
        : (widget.animationType == TransitionType.fade)
            ? new FadeTransition(
                opacity: _tween.animate(_animation),
                child: new RawImage(image: _imageInfo.image))
            : new SlideTransition(
                position: _tween.animate(_animation),
                child: new RawImage(image: _imageInfo.image));
  }
}
