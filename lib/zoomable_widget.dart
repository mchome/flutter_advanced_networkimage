library zoomable_widget;

import 'package:flutter/widgets.dart';

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

  Map<String, double> _containerSize = {
    'height': 0.0,
    'width': 0.0,
  };

  AnimationController _controller;
  Animation<double> _zoomAnimation;
  Animation<Offset> _panOffsetAnimation;

  @override
  initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    super.initState();
  }

  @override
  dispose() {
    _controller.dispose();
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
    Map<String, double> _boundarySize = {
      'height': _containerSize['height'] / 2,
      'width': _containerSize['width'] / 2,
    };
    if (details.scale != 1.0) {
      setState(() {
        _zoom = (_previewZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);

        _boundarySize = {
          'height': _boundarySize['height'] / _zoom * widget.panLimit,
          'width': _boundarySize['width'] / _zoom * widget.panLimit,
        };
      });
    }
    if ((widget.singleFingerPan && details.scale == 1.0) ||
        (widget.multiFingersPan && details.scale != 1.0)) {
      setState(() {
        Offset tmpOffset = (details.focalPoint -
                _zoomOriginOffset +
                _previewPanOffset * _previewZoom) /
            _zoom;
        _panOffset = widget.panLimit != 0.0
            ? Offset(
                tmpOffset.dx
                    .clamp(-_boundarySize['width'], _boundarySize['width']),
                tmpOffset.dy
                    .clamp(-_boundarySize['height'], _boundarySize['height']))
            : tmpOffset;
      });
    }
  }

  _handleReset() {
    _zoomAnimation = Tween(begin: 1.0, end: _zoom)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
          ..addListener(() => setState(() => _zoom = _zoomAnimation.value));
    _panOffsetAnimation = Tween(begin: Offset.zero, end: _panOffset)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
          ..addListener(
              () => setState(() => _panOffset = _panOffsetAnimation.value));
    if (_zoom < 0)
      _controller.forward(from: 1.0);
    else
      _controller.reverse(from: 1.0);
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
              _containerSize = {
                'height': box.maxHeight,
                'width': box.maxWidth,
              };
              return _child(widget.child);
            }),
          ),
          LayoutId(
            id: _ZoomableWidgetLayout.gestureContainer,
            child: GestureDetector(
              child: Container(color: Color(0)),
              onScaleStart: widget.enableZoom ? _onScaleStart : null,
              onScaleUpdate: widget.enableZoom ? _onScaleUpdate : null,
              onDoubleTap: _handleReset,
              onTap: widget.onTap,
            ),
          ),
        ]);
  }

  Widget _child(Widget _child) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(_zoom, _zoom),
      child: Transform(
        transform: Matrix4.identity()..translate(_panOffset.dx, _panOffset.dy),
        child: _child,
      ),
    );
  }
}
