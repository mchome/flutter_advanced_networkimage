import 'package:flutter/widgets.dart';

class ZoomableWidget extends StatefulWidget {
  const ZoomableWidget({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enableZoom: true,
    this.enablePan: true,
    this.child,
  })
      : assert(minScale != null),
        assert(maxScale != null),
        assert(enableZoom != null),
        assert(enablePan != null);

  final double maxScale;
  final double minScale;
  final bool enableZoom;
  final bool enablePan;
  final Widget child;

  @override
  ZoomableWidgetState createState() => new ZoomableWidgetState();
}

class ZoomableWidgetState extends State<ZoomableWidget> {
  double zoom = 1.0;
  double previewZoom = 1.0;
  Offset previewPanOffset = Offset.zero;
  Offset panOffset = Offset.zero;
  Offset zoomOriginOffset = Offset.zero;

  _onScaleStart(ScaleStartDetails details) => setState(() {
    zoomOriginOffset = details.focalPoint;
    previewPanOffset = panOffset;
    previewZoom = zoom;
  });
  _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      setState(() {
        zoom = (previewZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
        panOffset = details.focalPoint - (zoomOriginOffset - previewPanOffset) / previewZoom * zoom;
      });
    }
  }
  _handleReset() {
    setState(() {
      zoom = 1.0;
      previewZoom = 1.0;
      zoomOriginOffset = Offset.zero;
      previewPanOffset = Offset.zero;
      panOffset = Offset.zero;
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
            )
        ),
      ]
    );
  }

  Widget _child(Widget child) {
    return new Transform(
      transform: new Matrix4.identity()..scale(zoom, zoom),
      child: new Transform(
        transform: new Matrix4.translationValues(panOffset.dx, panOffset.dy, 0.0),
        child: child,
      ),
    );
  }
}

class _ZoomableWidgetLayout extends MultiChildLayoutDelegate {
  _ZoomableWidgetLayout();

  static final String gestureContainer = 'gesturecontainer';
  static final String painter = 'painter';

  @override
  void performLayout(Size size) {
    layoutChild(gestureContainer, new BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(gestureContainer, Offset.zero);
    layoutChild(painter, new BoxConstraints.tightFor(width: size.width, height: size.height));
    positionChild(painter, Offset.zero);
  }

  @override
  bool shouldRelayout(_ZoomableWidgetLayout oldDelegate) => false;
}