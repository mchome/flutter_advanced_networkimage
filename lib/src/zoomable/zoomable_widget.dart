import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:flutter_advanced_networkimage/src/utils.dart';

class ZoomableWidget extends StatefulWidget {
  ZoomableWidget({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.initialScale: 1.0,
    this.initialOffset: Offset.zero,
    this.initialRotation: 0.0,
    this.enableZoom: true,
    this.panLimit: 1.0,
    this.singleFingerPan: true,
    this.multiFingersPan: true,
    this.enableRotate: false,
    this.child,
    this.onTap,
    this.zoomSteps: 0,
    this.autoCenter: false,
    this.bounceBackBoundary: true,
    this.enableFling: true,
    this.flingFactor: 1.0,
    this.onZoomChanged,
    this.resetDuration: const Duration(milliseconds: 250),
    this.resetCurve: Curves.easeInOut,
  })  : assert(minScale != null),
        assert(maxScale != null),
        assert(initialScale != null),
        assert(initialOffset != null),
        assert(initialRotation != null),
        assert(enableZoom != null),
        assert(panLimit != null),
        assert(singleFingerPan != null),
        assert(multiFingersPan != null),
        assert(enableRotate != null),
        assert(zoomSteps != null),
        assert(autoCenter != null),
        assert(bounceBackBoundary != null),
        assert(enableFling != null),
        assert(flingFactor != null);

  /// The minimum size for scaling.
  final double minScale;

  /// The maximum size for scaling.
  final double maxScale;

  /// The initial scale.
  final double initialScale;

  /// The initial offset.
  final Offset initialOffset;

  /// The initial rotation.
  final double initialRotation;

  /// Allow zooming the child widget.
  final bool enableZoom;

  /// Allow panning with one finger.
  final bool singleFingerPan;

  /// Allow panning with more than one finger.
  final bool multiFingersPan;

  /// Allow rotating the [image].
  final bool enableRotate;

  /// Create a boundary with the factor.
  final double panLimit;

  /// The child widget that is display.
  final Widget child;

  /// Tap callback for this widget.
  final VoidCallback onTap;

  /// Allow users to zoom with double tap steps by steps.
  final int zoomSteps;

  /// Center offset when zooming to minimum scale.
  final bool autoCenter;

  /// Enable the bounce-back boundary.
  final bool bounceBackBoundary;

  /// Allow fling child widget after panning.
  final bool enableFling;

  /// Greater value create greater fling distance.
  final double flingFactor;

  /// When the scale value changed, the callback will be invoked.
  final ValueChanged<double> onZoomChanged;

  /// The duration of reset animation.
  final Duration resetDuration;

  /// The curve of reset animation.
  final Curve resetCurve;

  @override
  _ZoomableWidgetState createState() => _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget> {
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

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialScale;
    _pan = widget.initialOffset;
    _rotation = widget.initialRotation;
  }

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

    Size _marginSize = const Size(100.0, 100.0);

    _duration = const Duration(milliseconds: 50);
    _curve = Curves.easeOut;

    setState(() {
      if (widget.enableRotate)
        _rotation = (_previousRotation + details.rotation).clamp(-pi, pi);
      if (widget.enableZoom && details.scale != 1.0) {
        _zoom = (_previousZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
        if (widget.onZoomChanged != null) widget.onZoomChanged(_zoom);
      }
    });

    if ((widget.singleFingerPan && details.scale == 1.0) ||
        (widget.multiFingersPan && details.scale != 1.0)) {
      Offset _panRealOffset = (details.focalPoint -
              _zoomOriginOffset +
              _previousPanOffset * _previousZoom) /
          _zoom;

      if (widget.panLimit == 0.0) {
        _pan = _panRealOffset;
      } else {
        Offset _baseOffset = Offset(
          _panRealOffset.dx
              .clamp(-boundarySize.width / 2, boundarySize.width / 2),
          _panRealOffset.dy
              .clamp(-boundarySize.height / 2, boundarySize.height / 2),
        );

        Offset _marginOffset = _panRealOffset - _baseOffset;
        double _widthFactor = sqrt(_marginOffset.dx.abs()) / _marginSize.width;
        double _heightFactor =
            sqrt(_marginOffset.dy.abs()) / _marginSize.height;
        _marginOffset = Offset(
          _marginOffset.dx * _widthFactor * 2,
          _marginOffset.dy * _heightFactor * 2,
        );
        _pan = _baseOffset + _marginOffset;
      }
      setState(() {});
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    Size boundarySize = _boundarySize;

    _duration = widget.resetDuration;
    _curve = widget.resetCurve;

    final Offset velocity = details.velocity.pixelsPerSecond;
    final double magnitude = velocity.distance;
    if (magnitude > 800.0 * _zoom && widget.enableFling) {
      final Offset direction = velocity / magnitude;
      final double distance = (Offset.zero & context.size).shortestSide;
      final Offset endOffset =
          _pan + direction * distance * widget.flingFactor * 0.5;
      _pan = Offset(
        endOffset.dx.clamp(-boundarySize.width / 2, boundarySize.width / 2),
        endOffset.dy.clamp(-boundarySize.height / 2, boundarySize.height / 2),
      );
    }
    Offset _clampedOffset = Offset(
      _pan.dx.clamp(-boundarySize.width / 2, boundarySize.width / 2),
      _pan.dy.clamp(-boundarySize.height / 2, boundarySize.height / 2),
    );
    if (_zoom == widget.minScale && widget.autoCenter) {
      _clampedOffset = Offset.zero;
    }
    setState(() => _pan = _clampedOffset);
  }

  Size get _boundarySize {
    Size _boundarySize = Size(
          (_containerSize.width == _childSize.width)
              ? (_containerSize.width - _childSize.width / _zoom).abs()
              : (_containerSize.width - _childSize.width * _zoom).abs() / _zoom,
          (_containerSize.height == _childSize.height)
              ? (_containerSize.height - _childSize.height / _zoom).abs()
              : (_containerSize.height - _childSize.height * _zoom).abs() /
                  _zoom,
        ) *
        widget.panLimit;

    return _boundarySize;
  }

  void _handleDoubleTap() {
    double _stepLength = 0.0;

    _duration = widget.resetDuration;
    _curve = widget.resetCurve;

    if (widget.zoomSteps > 0)
      _stepLength = (widget.maxScale - 1.0) / widget.zoomSteps;

    double _tmpZoom = _zoom + _stepLength;
    if (_tmpZoom > widget.maxScale || _stepLength == 0.0) _tmpZoom = 1.0;

    setState(() {
      _zoom = _tmpZoom;
      if (widget.onZoomChanged != null) widget.onZoomChanged(_zoom);
      _pan = Offset.zero;
      _rotation = 0.0;
      _previousZoom = _tmpZoom;
      if (_tmpZoom == 1.0) {
        _zoomOriginOffset = Offset.zero;
        _previousPanOffset = Offset.zero;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return SizedBox();

    return CustomMultiChildLayout(
      delegate: _ZoomableWidgetLayout(),
      children: <Widget>[
        LayoutId(
          id: _ZoomableWidgetLayout.painter,
          child: _ZoomableChild(
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
        ),
        LayoutId(
          id: _ZoomableWidgetLayout.gestureContainer,
          child: GestureDetector(
            child: Container(color: Color(0)),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: widget.bounceBackBoundary ? _onScaleEnd : null,
            onDoubleTap: _handleDoubleTap,
            onTap: widget.onTap,
          ),
        ),
      ],
    );
  }
}

class _ZoomableWidgetLayout extends MultiChildLayoutDelegate {
  _ZoomableWidgetLayout();

  static final String gestureContainer = 'gesturecontainer';
  static final String painter = 'painter';

  @override
  void performLayout(Size size) {
    layoutChild(gestureContainer,
        BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(gestureContainer, Offset.zero);
    layoutChild(painter,
        BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(painter, Offset.zero);
  }

  @override
  bool shouldRelayout(_ZoomableWidgetLayout oldDelegate) => false;
}

class _ZoomableChild extends ImplicitlyAnimatedWidget {
  const _ZoomableChild({
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
      _ZoomableChildState();
}

class _ZoomableChildState extends AnimatedWidgetBaseState<_ZoomableChild> {
  DoubleTween _zoom;
  OffsetTween _panOffset;
  // OffsetTween _zoomOriginOffset;
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
