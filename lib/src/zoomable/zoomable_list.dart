import 'package:flutter/widgets.dart';

class ZoomableList extends StatefulWidget {
  ZoomableList({
    Key key,
    @required this.child,
    this.childKey,
    this.maxScale: 1.4,
    this.enablePan: true,
    this.enableZoom: true,
    this.maxWidth,
    this.maxHeight: double.infinity,
    this.zoomSteps: 0,
    this.enableFling: true,
    this.flingFactor: 1.0,
    this.onTap,
  })  : assert(maxScale != null),
        assert(enablePan != null),
        assert(enableZoom != null),
        assert(zoomSteps != null),
        assert(enableFling != null),
        assert(flingFactor != null);

  final Widget child;
  @deprecated
  final GlobalKey childKey;
  final double maxScale;
  final bool enableZoom;
  final bool enablePan;
  final double maxWidth;
  final double maxHeight;
  final int zoomSteps;
  final bool enableFling;
  final double flingFactor;
  final VoidCallback onTap;

  @override
  _ZoomableListState createState() => _ZoomableListState();
}

class _ZoomableListState extends State<ZoomableList>
    with TickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();

  double _zoom = 1.0;
  double _previewZoom = 1.0;
  Offset _previewPanOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Offset _startTouchOriginOffset = Offset.zero;

  Size _containerSize = Size.zero;
  Size _widgetSize = Size.zero;
  bool _getContainerSize = false;

  AnimationController _controller;
  AnimationController _flingController;
  Animation<double> _zoomAnimation;
  Animation<Offset> _panOffsetAnimation;
  Animation<Offset> _flingAnimation;

  @override
  void initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    _flingController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _flingController.dispose();
    super.dispose();
  }

  void _handleReset() {
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

  void _onScaleStart(ScaleStartDetails details) {
    _flingController.stop();
    setState(() {
      _startTouchOriginOffset = details.focalPoint;
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_getContainerSize) {
      final RenderBox box = _key.currentContext.findRenderObject();
      if (box.size == _containerSize) {
        _getContainerSize = true;
      } else {
        _containerSize = box.size;
      }
    }
    Size _boundarySize = Size(_containerSize.width / 2, _containerSize.height);
    if (widget.enableZoom) {
      setState(() {
        if (details.scale == 1.0) {
          Offset _tmpOffset = (details.focalPoint -
                  _startTouchOriginOffset +
                  _previewPanOffset * _previewZoom) /
              _zoom;
          _panOffset = Offset(
            _tmpOffset.dx.clamp(
              -_boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
              _boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
            ),
            _tmpOffset.dy.clamp(
              _widgetSize.height / 2 * (2 / _zoom) - _boundarySize.height,
              _widgetSize.height / 2 * (_zoom - 1.0) / (widget.maxScale - 1.0),
            ),
          );
        } else {
          _zoom = (_previewZoom * details.scale).clamp(1.0, widget.maxScale);
          _panOffset = Offset(
            _panOffset.dx.clamp(
              -_boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
              _boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
            ),
            _panOffset.dy.clamp(
              _widgetSize.height / 2 * (2 / _zoom) - _boundarySize.height,
              _widgetSize.height / 2 * (_zoom - 1.0) / (widget.maxScale - 1.0),
            ),
          );
        }
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_getContainerSize) {
      final RenderBox box = _key.currentContext.findRenderObject();
      if (box.size == _containerSize) {
        _getContainerSize = true;
      } else {
        _containerSize = box.size;
      }
    }
    Size _boundarySize = Size(_containerSize.width / 2, _containerSize.height);
    final Offset velocity = details.velocity.pixelsPerSecond;
    final double magnitude = velocity.distance;
    if (magnitude > 800.0 * _zoom && widget.enableFling) {
      final Offset direction = velocity / magnitude;
      final double distance = (Offset.zero & context.size).shortestSide;
      final Offset endOffset =
          _panOffset + direction * distance * widget.flingFactor * 0.5;
      _flingAnimation = Tween(
        begin: _panOffset,
        end: Offset(
          endOffset.dx.clamp(
            -_boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
            _boundarySize.width * (_zoom - 1.0) / (widget.maxScale - 1.0),
          ),
          endOffset.dy.clamp(
            _widgetSize.height / 2 * (2 / _zoom) - _boundarySize.height,
            _widgetSize.height / 2 * (_zoom - 1.0) / (widget.maxScale - 1.0),
          ),
        ),
      ).animate(_flingController)
        ..addListener(() => setState(() => _panOffset = _flingAnimation.value));

      _flingController
        ..value = 0.0
        ..fling(velocity: magnitude / 1000.0);
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
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
              _widgetSize = Size(box.minWidth, box.minHeight);
              return Transform(
                origin: Offset(_containerSize.width / 2 - _panOffset.dx,
                    _widgetSize.height / 2 - _panOffset.dy),
                transform: Matrix4.identity()
                  ..translate(_panOffset.dx, _panOffset.dy)
                  ..scale(_zoom, _zoom),
                child: Container(key: _key, child: widget.child),
              );
            }),
          ),
        ),
        LayoutId(
          id: _ZoomableListLayout.gestureContainer,
          child: GestureDetector(
            child: Container(color: Color(0)),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onDoubleTap: _handleReset,
            onTap: widget.onTap,
          ),
        ),
      ],
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
