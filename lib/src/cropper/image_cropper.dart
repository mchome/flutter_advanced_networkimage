/// WIP, do not use it

// import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/src/utils.dart';

class ImageCropper extends StatefulWidget {
  ImageCropper({
    Key key,
    @required this.child,
    this.minScale: 1.0,
    this.maxScale: 3.0,
    @required this.onCropperChanged,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  final ValueChanged<Uint8List> onCropperChanged;

  @override
  _ImageCropperState createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  final GlobalKey _key = GlobalKey();

  double _zoom = 1.0;
  double _previousZoom = 1.0;
  Offset _previousPanOffset = Offset.zero;
  Offset _pan = Offset.zero;
  Offset _zoomOriginOffset = Offset.zero;
  double _rotation = 0.0;
  double _previousRotation = 0.0;

  Size _childSize = Size.zero;
  Size _containerSize = Size.zero;

  Duration _duration = const Duration(milliseconds: 100);
  Curve _curve = Curves.easeOut;

  void _onScaleStart(ScaleStartDetails details) {
    if (_childSize == Size.zero) {
      final RenderBox renderbox = _key.currentContext.findRenderObject();
      _childSize = renderbox.size;
    }
    setState(() {
      _zoomOriginOffset = details.focalPoint;
      _previousPanOffset = _pan;
      _previousZoom = _zoom;
      _previousRotation = _rotation;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    Size boundarySize = _boundarySize;

    Size _marginSize = Size(100.0, 100.0);

    _duration = const Duration(milliseconds: 50);
    _curve = Curves.easeOut;

    // apply rotate
    // setState(() {
    //   _rotation = (_previousRotation + details.rotation).clamp(-pi, pi);
    // });

    if (details.scale != 1.0) {
      setState(() {
        _zoom = (_previousZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    Size boundarySize = _boundarySize;
  }

  Size get _boundarySize {
    Size _boundarySize = Size(
      (_containerSize.width == _childSize.width)
          ? (_containerSize.width - _childSize.width / _zoom).abs()
          : (_containerSize.width - _childSize.width * _zoom).abs() / _zoom,
      (_containerSize.height == _childSize.height)
          ? (_containerSize.height - _childSize.height / _zoom).abs()
          : (_containerSize.height - _childSize.height * _zoom).abs() / _zoom,
    );

    return _boundarySize;
  }

  void _handleDoubleTap() {
    _duration = const Duration(milliseconds: 250);
    _curve = Curves.easeInOut;

    setState(() {
      _zoom = 0.0;
      _pan = Offset.zero;
      _rotation = 0.0;
      _previousZoom = 0.0;
      _zoomOriginOffset = Offset.zero;
      _previousPanOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onDoubleTap: _handleDoubleTap,
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            _AnimatedCropper(
              duration: _duration,
              curve: _curve,
              zoom: _zoom,
              panOffset: _pan,
              rotation: _rotation,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  _containerSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return Center(
                    child: Container(key: _key, child: widget.child),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCropper extends ImplicitlyAnimatedWidget {
  const _AnimatedCropper({
    Duration duration,
    Curve curve = Curves.linear,
    @required this.zoom,
    @required this.panOffset,
    @required this.rotation,
    @required this.child,
  }) : super(duration: duration, curve: curve);

  final double zoom;
  final Offset panOffset;
  final double rotation;
  final Widget child;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() =>
      _AnimatedCropperState();
}

class _AnimatedCropperState extends AnimatedWidgetBaseState<_AnimatedCropper> {
  DoubleTween _zoom;
  OffsetTween _panOffset;
  OffsetTween _zoomOriginOffset;
  DoubleTween _rotation;

  @override
  void forEachTween(visitor) {
    _zoom = visitor(
        _zoom, widget.zoom, (dynamic value) => DoubleTween(begin: value));
    _panOffset = visitor(_panOffset, widget.panOffset,
        (dynamic value) => OffsetTween(begin: value));
    _rotation = visitor(_rotation, widget.rotation,
        (dynamic value) => DoubleTween(begin: value));
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      origin: Offset(-_panOffset.evaluate(animation).dx,
          -_panOffset.evaluate(animation).dy),
      transform: Matrix4.identity()
        ..translate(_panOffset.evaluate(animation).dx,
            _panOffset.evaluate(animation).dy)
        ..scale(_zoom.evaluate(animation), _zoom.evaluate(animation)),
      child: Transform.rotate(
        angle: _rotation.evaluate(animation),
        child: widget.child,
      ),
    );
  }
}
