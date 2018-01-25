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
  Offset offset = Offset.zero;

  _onScaleStart(ScaleStartDetails details) {
    setState(() => offset = details.focalPoint);
  }
  _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      setState(() => zoom = (previewZoom * details.scale).clamp(widget.minScale, widget.maxScale));
    }
  }
  _onScaleEnd(ScaleEndDetails details) {
    previewZoom = zoom;
  }
  _handleReset() {
    setState(() {
      zoom = 1.0;
      previewZoom = 1.0;
      offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return new Container();
    return new GestureDetector(
      child: _child(widget.child),
      onScaleStart: widget.enableZoom ? _onScaleStart : null,
      onScaleUpdate: widget.enableZoom ? _onScaleUpdate : null,
      onScaleEnd: widget.enableZoom ? _onScaleEnd : null,
    );
  }

  Widget _child(Widget child) {
//    print('previewZoom: ' + previewZoom.toString());
//    print('zoom: ' + zoom.toString());
    return new FractionallySizedBox(
      widthFactor: zoom,
      child: child,
    );
  }
}
