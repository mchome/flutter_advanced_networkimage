/// WIP, do not use it

library image_cropper;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageCropper extends StatefulWidget {
  ImageCropper({
    Key key,
    @required this.image,
    @required this.onCropperChanged,
  });

  /// The target image that is cropped.
  final ImageProvider image;

  final ValueChanged<ByteData> onCropperChanged;

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

  ImageStream _imageStream;
  ui.Image _image;
  // AnimationController _resetZoomController;
  // AnimationController _resetPanController;
  // Animation<double> _zoomAnimation;
  // Animation<Offset> _panOffsetAnimation;

  ImageProvider get _imageProvider => widget.image;

  @override
  void initState() {
    // _resetZoomController =
    //     AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    // _resetPanController =
    //     AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    super.initState();
  }

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
    // _resetZoomController.dispose();
    // _resetPanController.dispose();
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

  void _updateImage(ImageInfo info, _) => setState(() => _image = info.image);

  void _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _zoomOriginOffset = details.focalPoint;
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Size _boundarySize = Size(_image.width / 2, _image.height / 2);
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
        });
      },
      child: ClipRect(
        child: CustomPaint(
          size: Size(_image.width.toDouble(), _image.height.toDouble()),
          painter: _GesturePainter(
            _image,
            _zoom,
            _panOffset,
            widget.onCropperChanged,
          ),
        ),
      ),
    );
  }
}

class _GesturePainter extends CustomPainter {
  const _GesturePainter(
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
  final ValueChanged<ByteData> onImageCropperChanged;

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = offset & (size * zoom);

    final recorder = ui.PictureRecorder();
    final cropperCanvas = Canvas(recorder, rect);

    paintImage(
      canvas: canvas,
      image: image,
      rect: rect,
      fit: BoxFit.contain,
    );
    paintImage(
      canvas: cropperCanvas,
      image: image,
      rect: rect,
      fit: BoxFit.contain,
    );

    recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt())
        .then((ui.Image image) {
      image
          .toByteData(format: ui.ImageByteFormat.png)
          .then((ByteData data) => onImageCropperChanged(data));
    });
  }

  @override
  bool shouldRepaint(_GesturePainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.zoom != zoom ||
        oldPainter.offset != offset;
  }
}
