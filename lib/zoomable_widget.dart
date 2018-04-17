library zoomable_widget;

import 'package:flutter/widgets.dart';

class _ZoomableWidgetLayout extends MultiChildLayoutDelegate {
  _ZoomableWidgetLayout();

  static final String gestureContainer = 'gesturecontainer';
  static final String painter = 'painter';

  @override
  void performLayout(Size size) {
    layoutChild(gestureContainer,
        new BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(gestureContainer, Offset.zero);
    layoutChild(painter,
        new BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(painter, Offset.zero);
  }

  @override
  bool shouldRelayout(_ZoomableWidgetLayout oldDelegate) => false;
}

class ZoomableWidget extends StatefulWidget {
  const ZoomableWidget({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enableZoom: true,
    this.enablePan: true,
    this.child,
    this.tapCallback,
  })  : assert(minScale != null),
        assert(maxScale != null),
        assert(enableZoom != null),
        assert(enablePan != null);

  final double maxScale;
  final double minScale;
  final bool enableZoom;
  final bool enablePan;
  final Widget child;
  final Function tapCallback;

  @override
  _ZoomableWidgetState createState() => new _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget>
    with TickerProviderStateMixin {
  double _zoom = 1.0;
  double _previewZoom = 1.0;
  Offset _previewPanOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Offset _zoomOriginOffset = Offset.zero;

  AnimationController _controller;
  Animation<double> _zoomAnimation;
  Animation<Offset> _panOffsetAnimation;

  @override
  initState() {
    _controller = new AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
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
    if (details.scale != 1.0) {
      setState(() {
        _zoom = (_previewZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
        _panOffset = (details.focalPoint -
                _zoomOriginOffset +
                _previewPanOffset * _previewZoom) /
            _zoom;
      });
    }
  }

  _handleReset() {
    _zoomAnimation = new Tween(begin: 1.0, end: _zoom).animate(
        new CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
      ..addListener(() => setState(() => _zoom = _zoomAnimation.value));
    _panOffsetAnimation = new Tween(begin: Offset.zero, end: _panOffset)
        .animate(
            new CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
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
    if (widget.child == null) return new Container();
    return new CustomMultiChildLayout(
        delegate: new _ZoomableWidgetLayout(),
        children: <Widget>[
          new LayoutId(
            id: _ZoomableWidgetLayout.painter,
            child: _child(widget.child),
          ),
          new LayoutId(
              id: _ZoomableWidgetLayout.gestureContainer,
              child: new GestureDetector(
                child: new Container(color: new Color(0)),
                onScaleStart: widget.enableZoom ? _onScaleStart : null,
                onScaleUpdate: widget.enableZoom ? _onScaleUpdate : null,
                onDoubleTap: _handleReset,
                onTap: widget.tapCallback,
              )),
        ]);
  }

  Widget _child(Widget _child) {
    return new Transform(
      alignment: Alignment.center,
      transform: new Matrix4.identity()..scale(_zoom, _zoom),
      child: new Transform(
        transform: new Matrix4.identity()
          ..translate(_panOffset.dx, _panOffset.dy),
        child: _child,
      ),
    );
  }
}
