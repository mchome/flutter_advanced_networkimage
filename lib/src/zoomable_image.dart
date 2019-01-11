/// WIP, do not use it

import 'package:flutter/widgets.dart';

class ZoomableImage extends StatefulWidget {
  ZoomableImage({
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
    this.autoCenter: false,
    this.bounceBackBoundary: true,
    this.onZoomStateChanged,
  })  : assert(minScale != null),
        assert(maxScale != null),
        assert(enableZoom != null);

  /// The minimum size for scaling.
  final double minScale;

  /// The maximum size for scaling.
  final double maxScale;

  /// Allow zooming the child widget.
  final bool enableZoom;

  /// Allow panning with one finger.
  final bool singleFingerPan;

  /// Allow panning with more than one finger.
  final bool multiFingersPan;

  /// Create a boundary with the factor.
  final double panLimit;

  /// The child widget that is display.
  final Widget child;

  /// Tap callback for this widget.
  final Function onTap;

  /// Allow users to zoom with double tap steps by steps.
  final int zoomSteps;

  /// Center offset when zooming to min scale.
  final bool autoCenter;

  /// Enable the bounce-back boundary.
  final bool bounceBackBoundary;

  /// When the scale value changed, the callback will be invoked.
  final ValueChanged<double> onZoomStateChanged;

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return null;
  }
}
