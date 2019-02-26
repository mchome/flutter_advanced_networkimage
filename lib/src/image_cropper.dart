/// WIP, do not use it

library image_cropper;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageCropper extends StatefulWidget {
  ImageCropper({
    Key key,
    @required this.image,
    this.minScale: 1.0,
    this.maxScale: 3.0,
    @required this.onCropperChanged,
  });

  final ImageProvider image;
  final double minScale;
  final double maxScale;

  final ValueChanged<Uint8List> onCropperChanged;

  @override
  _ImageCropperState createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper>
    with TickerProviderStateMixin {
  double _zoom = 1.0;
  double _previousZoom = 1.0;
  Offset _previousPanOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Offset _zoomOriginOffset = Offset.zero;
  double _rotation = 0.0;
  double _previousRotation = 0.0;

  ImageStream _imageStream;
  ImageInfo _image;

  ImageProvider get _imageProvider => widget.image;

  @override
  void didChangeDependencies() {
    _getImage();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(ImageCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _getImage();
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_updateImage);
    super.dispose();
  }

  void _getImage() {
    final ImageStream oldImageStream = _imageStream;
    _imageStream =
        _imageProvider.resolve(createLocalImageConfiguration(context));
    if (_imageStream.key != oldImageStream?.key) {
      oldImageStream?.removeListener(_updateImage);
      _imageStream.addListener(_updateImage);
    }
  }

  void _updateImage(ImageInfo info, _) => setState(() => _image = info);

  void _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _zoomOriginOffset = details.focalPoint;
      _previousPanOffset = _panOffset;
      _previousZoom = _zoom;
      _previousRotation = _rotation;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Size _boundarySize = Size(_image.width / 2, _image.height / 2);
    setState(() {
      _rotation = (_previousRotation + details.rotation).clamp(-pi, pi);
      if (details.scale != 1.0) {
        _zoom = (_previousZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
      } else {
        Offset _panRealOffset = details.focalPoint -
            ((_zoomOriginOffset - _previousPanOffset) / _previousZoom) * _zoom;
        _panOffset = _panRealOffset;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return Center(child: CircularProgressIndicator());

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onDoubleTap: () {
        setState(() {
          _panOffset = Offset.zero;
          _zoom = 1.0;
          _rotation = 0.0;
        });
      },
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            AnimatedCropper(
              image: _image,
              zoom: _zoom,
              panOffset: _panOffset,
              rotation: _rotation,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            ),
            CustomPaint(
              size: Size(_image.image.width.toDouble(),
                  _image.image.height.toDouble()),
              painter: _RecordPainter(
                _image.image,
                _zoom,
                _panOffset,
                _rotation,
                widget.onCropperChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedCropper extends ImplicitlyAnimatedWidget {
  const AnimatedCropper({
    @required this.image,
    @required this.zoom,
    this.panOffset: Offset.zero,
    this.rotation: 0.0,
    Duration duration,
    Curve curve = Curves.linear,
    this.enableRotate: false,
  }) : super(duration: duration, curve: curve);

  final ImageInfo image;
  final double zoom;
  final Offset panOffset;
  final double rotation;
  final bool enableRotate;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() =>
      _AnimatedCropperState();
}

class _AnimatedCropperState extends AnimatedWidgetBaseState<AnimatedCropper> {
  _DoubleTween _zoom;
  _OffsetTween _panOffset;
  _DoubleTween _rotation;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(
        widget.image.image.width.toDouble(),
        widget.image.image.height.toDouble(),
      ),
      painter: _PreviewPainter(
        widget.image.image,
        _zoom.evaluate(animation),
        _panOffset.evaluate(animation),
        _rotation.evaluate(animation),
        widget.enableRotate,
      ),
    );
  }

  @override
  void forEachTween(visitor) {
    _zoom = visitor(
        _zoom, widget.zoom, (dynamic value) => _DoubleTween(begin: value));
    _panOffset = visitor(_panOffset, widget.panOffset,
        (dynamic value) => _OffsetTween(begin: value));
    _rotation = visitor(_rotation, widget.rotation,
        (dynamic value) => _DoubleTween(begin: value));
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(
    this.image,
    this.zoom,
    this.offset,
    this.angle,
    this.enableRotate,
  )   : assert(image != null),
        assert(zoom != null),
        assert(offset != null);

  final ui.Image image;
  final double zoom;
  final Offset offset;
  final double angle;
  final bool enableRotate;

  @override
  void paint(Canvas canvas, Size size) {
    customPaintImage(
      canvas: canvas,
      image: image,
      size: size,
      offset: offset,
      scale: zoom,
      angle: angle,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.zoom != zoom ||
        oldPainter.offset != offset ||
        oldPainter.angle != angle ||
        oldPainter.enableRotate != enableRotate;
  }
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter(
    this.image,
    this.zoom,
    this.offset,
    this.angle,
    this.onImageCropperChanged,
  )   : assert(image != null),
        assert(zoom != null),
        assert(offset != null);

  final ui.Image image;
  final double zoom;
  final Offset offset;
  final double angle;
  final ValueChanged<Uint8List> onImageCropperChanged;

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;

    final recorder = ui.PictureRecorder();
    final cropperCanvas = Canvas(recorder, rect);

    customPaintImage(
      canvas: cropperCanvas,
      image: image,
      size: size,
      offset: offset,
      scale: zoom,
      angle: angle,
    );

    recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt())
        .then((ui.Image image) {
      image.toByteData(format: ui.ImageByteFormat.png).then((ByteData data) =>
          onImageCropperChanged(Uint8List.view(data.buffer)));
    });
  }

  @override
  bool shouldRepaint(_RecordPainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.zoom != zoom ||
        oldPainter.offset != offset ||
        oldPainter.angle != angle;
  }
}

void customPaintImage({
  @required Canvas canvas,
  @required ui.Image image,
  @required Size size,
  double angle = 0.0,
  Offset offset = Offset.zero,
  double scale = 1.0,
  ColorFilter colorFilter,
  BoxFit fit: BoxFit.contain,
  bool flipHorizontally = false,
  bool invertColors = false,
  FilterQuality filterQuality = FilterQuality.low,
}) {
  assert(canvas != null);
  assert(image != null);
  assert(flipHorizontally != null);

  const Alignment alignment = Alignment.center;
  Rect rect = Offset.zero & size;
  if (rect.isEmpty) return;
  Size inputSize = Size(image.width.toDouble(), image.height.toDouble());
  final FittedSizes fittedSizes = applyBoxFit(fit, inputSize, size);
  final Size sourceSize = fittedSizes.source;
  Size destinationSize = fittedSizes.destination;
  final Paint paint = Paint()..isAntiAlias = false;
  if (colorFilter != null) paint.colorFilter = colorFilter;
  if (sourceSize != destinationSize) paint.filterQuality = filterQuality;
  paint.invertColors = invertColors;
  final double halfWidthDelta = (size.width - destinationSize.width) / 2.0;
  final double halfHeightDelta = (size.height - destinationSize.height) / 2.0;
  final double dx = halfWidthDelta +
      (flipHorizontally ? -alignment.x : alignment.x) * halfWidthDelta;
  final double dy = halfHeightDelta + alignment.y * halfHeightDelta;
  final Offset destinationPosition = rect.topLeft.translate(dx, dy);
  final Rect destinationRect = destinationPosition & destinationSize;
  if (flipHorizontally) canvas.save();
  if (flipHorizontally) {
    final double dx = -(rect.left + rect.width / 2.0);
    canvas.translate(-dx, 0.0);
    canvas.scale(-1.0, 1.0);
    canvas.translate(dx, 0.0);
  }
  final Rect sourceRect =
      alignment.inscribe(sourceSize, Offset.zero & inputSize);

  final cDx = destinationSize.width;
  final cDy = destinationSize.height + destinationPosition.dy * 2;
  final double r = sqrt(cDx * cDx + cDy * cDy) / 2;
  final alpha = atan(cDy / cDx);
  final beta = alpha + angle;
  final shiftY = r * sin(beta);
  final shiftX = r * cos(beta);
  final translateX = cDx / 2 - shiftX;
  final translateY = cDy / 2 - shiftY;
  canvas.translate(translateX * scale, translateY * scale);
  canvas.translate(offset.dx, offset.dy);
  canvas.scale(scale);
  canvas.rotate(angle);

  canvas.drawImageRect(image, sourceRect, destinationRect, paint);

  if (flipHorizontally) canvas.restore();
}

class _DoubleTween extends Tween<double> {
  _DoubleTween({double begin, double end}) : super(begin: begin, end: end);

  @override
  double lerp(double t) => (begin + (end - begin) * t);
}

class _OffsetTween extends Tween<Offset> {
  _OffsetTween({Offset begin, Offset end}) : super(begin: begin, end: end);

  @override
  Offset lerp(double t) => (begin + (end - begin) * t);
}
