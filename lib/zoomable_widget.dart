library zoomable_widget;

import 'dart:math';

import 'package:flutter/widgets.dart';

class _ZoomableWidgetLayout extends MultiChildLayoutDelegate {
  _ZoomableWidgetLayout();

  static final String gestureContainer = 'gesturecontainer';
  static final String painter = 'painter';

  @override
  performLayout(Size size) {
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

class ZoomableWidget extends StatefulWidget {
  ZoomableWidget({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enableZoom: true,
    this.panLimit: 1.0,
    this.singleFingerPan: true,
    this.multiFingersPan: true,
    this.child,
    this.onTap,
    this.zoomSteps: 0,
    this.bounceBackBoundary: true,
  })  : assert(minScale != null),
        assert(maxScale != null),
        assert(enableZoom != null);

  final double maxScale;
  final double minScale;
  final bool enableZoom;
  final bool singleFingerPan;
  final bool multiFingersPan;
  final double panLimit;
  final Widget child;
  final Function onTap;
  final int zoomSteps;
  final bool bounceBackBoundary;

  @override
  _ZoomableWidgetState createState() => _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget>
    with TickerProviderStateMixin {
  double _zoom = 1.0;
  double _previewZoom = 1.0;
  Offset _previewPanOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Offset _zoomOriginOffset = Offset.zero;

  Size _containerSize = Size.zero;

  AnimationController _resetController;
  AnimationController _bounceController;
  Animation<double> _zoomAnimation;
  Animation<Offset> _panOffsetAnimation;
  Animation<Offset> _bounceAnimation;

  @override
  initState() {
    _resetController = AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    _bounceController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    super.initState();
  }

  @override
  dispose() {
    _resetController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _zoomOriginOffset = details.focalPoint;
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
    });
  }

  _onScaleUpdate(ScaleUpdateDetails details) {
    Size _boundarySize =
        Size(_containerSize.width / 2, _containerSize.height / 2);
    Size _marginSize = Size(100.0, 100.0);
    if (widget.enableZoom && details.scale != 1.0) {
      setState(() {
        _zoom = (_previewZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
      });
    }
    if ((widget.singleFingerPan && details.scale == 1.0) ||
        (widget.multiFingersPan && details.scale != 1.0)) {
      setState(() {
        Offset _panRealOffset = (details.focalPoint -
                _zoomOriginOffset +
                _previewPanOffset * _previewZoom) /
            _zoom;

        if (widget.panLimit == 0.0) {
          _panOffset = _panRealOffset;
        } else {
          Offset _baseOffset = Offset(
              _panRealOffset.dx.clamp(
                -_boundarySize.width / _zoom * widget.panLimit,
                _boundarySize.width / _zoom * widget.panLimit,
              ),
              _panRealOffset.dy.clamp(
                -_boundarySize.height / _zoom * widget.panLimit,
                _boundarySize.height / _zoom * widget.panLimit,
              ));

          Offset _marginOffset = _panRealOffset - _baseOffset;
          double _widthFactor =
              sqrt(_marginOffset.dx.abs()) / _marginSize.width;
          double _heightFactor =
              sqrt(_marginOffset.dy.abs()) / _marginSize.height;
          _marginOffset = Offset(
            _marginOffset.dx * _widthFactor,
            _marginOffset.dy * _heightFactor,
          );
          _panOffset = _baseOffset + _marginOffset;
        }
      });
    }
  }

  _onScaleEnd(_) {
    Size _boundarySize =
        Size(_containerSize.width / 2, _containerSize.height / 2);
    Animation _animation =
        CurvedAnimation(parent: _bounceController, curve: Curves.bounceInOut);
    Offset _borderOffset = Offset(
      _panOffset.dx.clamp(
        -_boundarySize.width / _zoom * widget.panLimit,
        _boundarySize.width / _zoom * widget.panLimit,
      ),
      _panOffset.dy.clamp(
        -_boundarySize.height / _zoom * widget.panLimit,
        _boundarySize.height / _zoom * widget.panLimit,
      ),
    );
    _bounceAnimation = Tween(begin: _panOffset, end: _borderOffset).animate(
        _animation)
      ..addListener(() => setState(() => _panOffset = _bounceAnimation.value));
    _bounceController.forward(from: 0.0);
  }

  _handleDoubleTap() {
    double _stepLength;
    Animation _animation =
        CurvedAnimation(parent: _resetController, curve: Curves.easeInOut);

    widget.zoomSteps > 0
        ? _stepLength = widget.maxScale / widget.zoomSteps
        : _stepLength = 0.0;

    // TODO: step zoom
    _zoomAnimation = Tween(begin: 1.0, end: _zoom).animate(_animation)
      ..addListener(() => setState(() => _zoom = _zoomAnimation.value));
    _panOffsetAnimation = Tween(begin: Offset.zero, end: _panOffset)
        .animate(_animation)
          ..addListener(
              () => setState(() => _panOffset = _panOffsetAnimation.value));

    if (_zoom < 0)
      _resetController.forward(from: 1.0);
    else
      _resetController.reverse(from: 1.0);

    setState(() {
      _previewZoom = 1.0;
      _zoomOriginOffset = Offset.zero;
      _previewPanOffset = Offset.zero;
      _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return Container();

    return CustomMultiChildLayout(
      delegate: _ZoomableWidgetLayout(),
      children: <Widget>[
        LayoutId(
          id: _ZoomableWidgetLayout.painter,
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
            _containerSize = Size(box.minWidth, box.minHeight);
            return _child(widget.child);
          }),
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

  Widget _child(Widget _child) {
    return Transform(
      alignment: Alignment.center,
      origin: Offset(-_panOffset.dx, -_panOffset.dy),
      transform: Matrix4.identity()
        ..translate(_panOffset.dx, _panOffset.dy)
        ..scale(_zoom, _zoom),
      child: _child,
    );
  }
}
