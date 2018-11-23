library zoomable_list;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ZoomableList extends StatefulWidget {
  ZoomableList({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enablePan: true,
    this.enableZoom: true,
    this.panLimit: 1.0,
    this.maxWidth,
    this.maxHeight: double.infinity,
    @required this.child,
    @required this.childKey,
    this.onTap,
  })  : assert(minScale != null),
        assert(maxScale != null),
        assert(enablePan != null),
        assert(enableZoom != null),
        assert(childKey != null);

  final double maxScale;
  final double minScale;
  final bool enableZoom;
  final bool enablePan;
  final double panLimit;
  final double maxWidth;
  final double maxHeight;
  final Widget child;
  final GlobalKey childKey;
  final Function onTap;

  @override
  _ZoomableListState createState() => _ZoomableListState();
}

class _ZoomableListState extends State<ZoomableList>
    with TickerProviderStateMixin {
  double _zoom = 1.0;
  double _previewZoom = 1.0;
  Offset _previewPanOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Offset _startTouchOriginOffset = Offset.zero;

  Size _containerSize = Size.zero;
  Size _widgetSize = Size.zero;
  bool _getContainerSize = false;

  AnimationController _controller;
  Animation<double> _zoomAnimation;
  Animation<Offset> _panOffsetAnimation;

  @override
  initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    super.initState();
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  _handleReset() {
    _zoomAnimation = Tween<double>(begin: 1.0, end: _zoom)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
          ..addListener(() => setState(() => _zoom = _zoomAnimation.value));
    _panOffsetAnimation = Tween<Offset>(
            begin: Offset(0.0, _panOffset.dy), end: _panOffset)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
          ..addListener(
              () => setState(() => _panOffset = _panOffsetAnimation.value));
    if (_zoom < 0)
      _controller.forward(from: 1.0);
    else
      _controller.reverse(from: 1.0);

    setState(() {
      _previewZoom = 1.0;
      _startTouchOriginOffset = Offset(0.0, _panOffset.dy);
      _previewPanOffset = Offset(0.0, _panOffset.dy);
      _panOffset = Offset(0.0, _panOffset.dy);
    });
  }

  _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _startTouchOriginOffset = details.focalPoint;
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
    });
  }

  _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_getContainerSize) {
      final RenderBox box = widget.childKey.currentContext.findRenderObject();
      if (box.size == _containerSize) {
        _getContainerSize = true;
      } else {
        _containerSize = box.size;
      }
    }
    Size _boundarySize = Size(_containerSize.width / 2 * widget.panLimit,
        _containerSize.height * widget.panLimit);
    if (widget.enableZoom) {
      setState(() {
        if (details.scale == 1.0) {
          Offset _tmpOffset = (details.focalPoint -
                  _startTouchOriginOffset +
                  _previewPanOffset * _previewZoom) /
              _zoom;
          _panOffset = widget.panLimit != 0.0
              ? Offset(
                  _zoom == 1.0
                      ? _tmpOffset.dx.clamp(0.0, 0.0)
                      : _tmpOffset.dx
                          .clamp(-_boundarySize.width, _boundarySize.width),
                  _zoom == 1.0
                      ? _tmpOffset.dy
                          .clamp(_widgetSize.height - _boundarySize.height, 0.0)
                      : _tmpOffset.dy.clamp(
                          _widgetSize.height / 2 * widget.panLimit -
                              _boundarySize.height,
                          _widgetSize.height / 2 * widget.panLimit))
              : _tmpOffset;
        } else {
          _zoom = (_previewZoom * details.scale)
              .clamp(widget.minScale, widget.maxScale);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return Container();

    return CustomMultiChildLayout(
      delegate: _ZoomableListLayout(),
      children: <Widget>[
        LayoutId(
          id: _ZoomableListLayout.painter,
          child: _child(widget.child),
        ),
        LayoutId(
          id: _ZoomableListLayout.gestureContainer,
          child: GestureDetector(
            child: Container(color: Color(0)),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onDoubleTap: _handleReset,
            onTap: widget.onTap,
          ),
        ),
      ],
    );
  }

  Widget _child(Widget _child) {
    return OverflowBox(
      alignment: Alignment.topCenter,
      maxWidth: widget.maxWidth,
      maxHeight: widget.maxHeight,
      child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        _widgetSize = Size(box.minWidth, box.minHeight);
        return Transform(
          origin: Offset(_containerSize.width / 2 - _panOffset.dx,
              _widgetSize.height / 2 - _panOffset.dy),
          transform: Matrix4.identity()
            ..translate(_panOffset.dx, _panOffset.dy)
            ..scale(_zoom, _zoom),
          child: _child,
        );
      }),
    );
  }
}

class _ZoomableListLayout extends MultiChildLayoutDelegate {
  _ZoomableListLayout();

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
  bool shouldRelayout(_ZoomableListLayout oldDelegate) => false;
}
