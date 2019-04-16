/// WIP, do not use it

library image_cropper;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/src/utils.dart';

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
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Size _boundarySize = Size(_image.width / 2, _image.height / 2);
    setState(() {
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
        });
      },
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            AnimatedCropper(
              image: _image,
              zoom: _zoom,
              panOffset: _panOffset,
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
    Duration duration,
    Curve curve = Curves.linear,
  }) : super(duration: duration, curve: curve);

  final ImageInfo image;
  final double zoom;
  final Offset panOffset;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() =>
      _AnimatedCropperState();
}

class _AnimatedCropperState extends AnimatedWidgetBaseState<AnimatedCropper> {
  DoubleTween _zoom;
  OffsetTween _panOffset;

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
      ),
    );
  }

  @override
  void forEachTween(visitor) {
    _zoom = visitor(
        _zoom, widget.zoom, (dynamic value) => DoubleTween(begin: value));
    _panOffset = visitor(_panOffset, widget.panOffset,
        (dynamic value) => OffsetTween(begin: value));
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(
    this.image,
    this.zoom,
    this.offset,
  )   : assert(image != null),
        assert(zoom != null),
        assert(offset != null);

  final ui.Image image;
  final double zoom;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    customPaintImage(
      canvas: canvas,
      image: image,
      size: size,
      offset: offset,
      scale: zoom,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.zoom != zoom ||
        oldPainter.offset != offset;
  }
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter(
    this.image,
    this.zoom,
    this.offset,
    this.onImageCropperChanged,
  )   : assert(image != null),
        assert(zoom != null),
        assert(offset != null);

  final ui.Image image;
  final double zoom;
  final Offset offset;
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
        oldPainter.offset != offset;
  }
}

void customPaintImage({
  @required Canvas canvas,
  @required ui.Image image,
  @required Size size,
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

  canvas.drawImageRect(image, sourceRect, destinationRect, paint);

  if (flipHorizontally) canvas.restore();
}
