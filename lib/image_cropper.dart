/// WIP, do not use it

library image_cropper;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageCropper extends StatefulWidget {
  ImageCropper(
    this.image, {
    Key key,
    this.minScale: 0.7,
    this.maxScale: 1.4,
    this.enableRotate: false,
    this.onImageCropperChanged,
  })  : assert(minScale != null),
        assert(maxScale != null);

  /// The target image that is cropped.
  final ImageProvider image;

  /// The minimum size for scaling.
  final double minScale;

  /// The maximum size for scaling.
  final double maxScale;

  /// Allow user to rotate the image.
  final bool enableRotate;

  final ValueChanged<ByteData> onImageCropperChanged;

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
  initState() {
    // _resetZoomController =
    //     AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    // _resetPanController =
    //     AnimationController(vsync: this, duration: Duration(milliseconds: 100));
    super.initState();
  }

  @override
  didChangeDependencies() {
    _getImage();
    super.didChangeDependencies();
  }

  @override
  didUpdateWidget(ImageCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _getImage();
  }

  @override
  dispose() {
    // _resetZoomController.dispose();
    // _resetPanController.dispose();
    _imageStream?.removeListener(_updateImage);
    super.dispose();
  }

  _getImage() {
    final ImageStream oldImageStream = _imageStream;
    _imageStream =
        _imageProvider.resolve(createLocalImageConfiguration(context));
    if (_imageStream.key != oldImageStream?.key) {
      oldImageStream?.removeListener(_updateImage);
      _imageStream.addListener(_updateImage);
    }
  }

  _updateImage(ImageInfo info, _) => setState(() => _image = info.image);

  _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _zoomOriginOffset = details.focalPoint;
      _previewPanOffset = _panOffset;
      _previewZoom = _zoom;
    });
  }

  _onScaleUpdate(ScaleUpdateDetails details) {
    // Size _boundarySize = Size(_image.width / 2, _image.height / 2);
    if (details.scale != 1.0) {
      setState(() {
        _zoom = (_previewZoom * details.scale)
            .clamp(widget.minScale, widget.maxScale);
      });
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
      child: CustomPaint(
        painter: _GesturePainter(
          _image,
          _zoom,
          _panOffset,
          widget.onImageCropperChanged,
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
  paint(Canvas canvas, Size size) {
    Rect displayRect = offset & (size * zoom);
    Rect cropRect = (offset + Offset(100.0, 0.0)) & (size * zoom);

    final _recorder = ui.PictureRecorder();
    final cropperCanvas = Canvas(_recorder);

    paintImage(
      canvas: canvas,
      rect: displayRect,
      image: image,
      fit: BoxFit.contain,
    );
    paintImage(
      canvas: cropperCanvas,
      rect: cropRect,
      image: image,
      fit: BoxFit.contain,
    );

    _recorder
        .endRecording()
        .toImage(image.width.toInt(), image.height.toInt())
        .toByteData(format: ui.ImageByteFormat.png)
        .then((data) => onImageCropperChanged(data));
  }

  @override
  bool shouldRepaint(_GesturePainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.zoom != zoom ||
        oldPainter.offset != offset;
  }
}
