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
    @required this.onCropperChanged,
  });

  final ImageProvider image;
  final ValueChanged<Uint8List> onCropperChanged;

  @override
  _ImageCropperState createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper>
    with TickerProviderStateMixin {
  double _zoom = 1.0;
  double _previewZoom = 1.0;
  Offset _previewPanOffset = Offset.zero;
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
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
      _previousRotation = _rotation;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Size _boundarySize = Size(_image.width / 2, _image.height / 2);
    setState(() =>
        _rotation = (_previousRotation + details.rotation).clamp(-pi, pi));
    if (details.scale != 1.0) {
      setState(() => _zoom = (_previewZoom * details.scale).clamp(1.0, 5.0));
    }
    setState(() {
      Offset _panRealOffset = details.focalPoint -
          ((_zoomOriginOffset - _previewPanOffset) / _previewZoom) * _zoom;

      _panOffset = _panRealOffset;
      // _panOffset = Offset(
      //     _panRealOffset.dx.clamp(
      //       -_boundarySize.width / _zoom,
      //       _boundarySize.width / _zoom,
      //     ),
      //     _panRealOffset.dy.clamp(
      //       -_boundarySize.height / _zoom,
      //       _boundarySize.height / _zoom,
      //     ));
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
            CustomPaint(
              size: Size(_image.image.width.toDouble(),
                  _image.image.height.toDouble()),
              painter: _PreviewPainter(
                _image.image,
                _zoom,
                _panOffset,
                _rotation,
              ),
            ),
            CustomPaint(
              size: Size(_image.image.width.toDouble(),
                  _image.image.height.toDouble()),
              painter: _GesturePainter(
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

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(
    this.image,
    this.zoom,
    this.offset,
    this.angle,
  )   : assert(image != null),
        assert(zoom != null),
        assert(offset != null);

  final ui.Image image;
  final double zoom;
  final Offset offset;
  final double angle;

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
        oldPainter.angle != angle;
  }
}

class _GesturePainter extends CustomPainter {
  const _GesturePainter(
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
      canvas: canvas,
      image: image,
      size: size,
      offset: offset,
      scale: zoom,
      angle: angle,
    );

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
  bool shouldRepaint(_GesturePainter oldPainter) {
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

  final double r =
      sqrt(image.width * image.width + image.height * image.height) / 2;
  final alpha = atan(image.height / image.width);
  final beta = alpha + angle;
  final shiftY = r * sin(beta);
  final shiftX = r * cos(beta);
  final translateX = image.width / 2 - shiftX;
  final translateY = image.height / 2 - shiftY;

  const Alignment alignment = Alignment.center;
  Rect rect = Offset.zero & size;
  if (rect.isEmpty) return;
  Size outputSize = rect.size;
  Size inputSize = Size(image.width.toDouble(), image.height.toDouble());
  final FittedSizes fittedSizes = applyBoxFit(fit, inputSize, outputSize);
  final Size sourceSize = fittedSizes.source;
  Size destinationSize = fittedSizes.destination;
  final Paint paint = Paint()..isAntiAlias = false;
  if (colorFilter != null) paint.colorFilter = colorFilter;
  if (sourceSize != destinationSize) paint.filterQuality = filterQuality;
  paint.invertColors = invertColors;
  final double halfWidthDelta =
      (outputSize.width - destinationSize.width) / 2.0;
  final double halfHeightDelta =
      (outputSize.height - destinationSize.height) / 2.0;
  final double dx = halfWidthDelta +
      (flipHorizontally ? -alignment.x : alignment.x) * halfWidthDelta;
  final double dy = halfHeightDelta + alignment.y * halfHeightDelta;
  final Offset destinationPosition = rect.topLeft.translate(dx, dy);
  final Rect destinationRect = destinationPosition & destinationSize;
  final bool needSave = flipHorizontally;
  if (needSave) canvas.save();
  if (flipHorizontally) {
    final double dx = -(rect.left + rect.width / 2.0);
    canvas.translate(-dx, 0.0);
    canvas.scale(-1.0, 1.0);
    canvas.translate(dx, 0.0);
  }
  canvas.translate(translateX + offset.dx, translateY + offset.dy);
  canvas.scale(scale);
  canvas.rotate(angle);
  final Rect sourceRect =
      alignment.inscribe(sourceSize, Offset.zero & inputSize);
  canvas.drawImageRect(image, sourceRect, destinationRect, paint);

  if (needSave) canvas.restore();
}
