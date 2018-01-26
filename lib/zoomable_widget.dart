import 'package:flutter/material.dart';

class ZoomableWidget extends StatefulWidget {
  const ZoomableWidget({
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enableZoom: true,
    this.enablePan: true,
    this.child,
  }) : assert(minScale != null),
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
  Offset zoomOffset = Offset.zero;
  Offset previewPanOffset = Offset.zero;
  Offset panOffset = Offset.zero;

  _onScaleStart(ScaleStartDetails details) => setState(() {
      zoomOffset = details.focalPoint / zoom;
      previewPanOffset = details.focalPoint / zoom;
    });
  _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      setState(() {
        zoom = (previewZoom * details.scale).clamp(widget.minScale, widget.maxScale);
        if (zoom > 1.0) {
          panOffset = (details.focalPoint - previewPanOffset) / zoom;
        } else {
          panOffset = Offset.zero;
        }
      });
    }
  }
  _onScaleEnd(ScaleEndDetails details) => previewZoom = zoom;
  _handleReset() => setState(() {
      zoom = 1.0;
      previewZoom = 1.0;
      zoomOffset = Offset.zero;
      previewPanOffset = Offset.zero;
      panOffset = Offset.zero;
    });

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return new Container();
    return new GestureDetector(
      child: _child(widget.child),
      onScaleStart: widget.enableZoom ? _onScaleStart : null,
      onScaleUpdate: widget.enableZoom ? _onScaleUpdate : null,
      onScaleEnd: widget.enableZoom ? _onScaleEnd : null,
      onDoubleTap: _handleReset,
    );
  }

  Widget _child(Widget child) {
    return new FractionallySizedBox(
      alignment: Alignment.center,
      widthFactor: (zoom <= 1.0) ? zoom : 1.0,
      child: new Transform(
        transform: (zoom > 1.0) ? (new Matrix4.identity()..scale(zoom, zoom)) : (new Matrix4.identity()..scale(1.0, 1.0)),
        origin: new Offset(zoomOffset.dx, zoomOffset.dy),
        child: new Transform(
          transform: new Matrix4.translationValues(panOffset.dx, panOffset.dy, 0.0),
          child: child,
        )
      )
    );
  }
}
