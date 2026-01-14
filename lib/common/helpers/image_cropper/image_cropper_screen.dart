import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Configuration ---
enum CropAspectRatio {
  original,
  free,
  square,
  ratio3x4,
  ratio4x3,
  ratio16x9,
  ratio9x16,
}

extension CropAspectRatioExtension on CropAspectRatio {
  String get label {
    switch (this) {
      case CropAspectRatio.original:
        return 'Original';
      case CropAspectRatio.free:
        return 'Free';
      case CropAspectRatio.square:
        return 'Square';
      case CropAspectRatio.ratio3x4:
        return '3:4';
      case CropAspectRatio.ratio4x3:
        return '4:3';
      case CropAspectRatio.ratio16x9:
        return '16:9';
      case CropAspectRatio.ratio9x16:
        return '9:16';
    }
  }

  double? get ratio {
    switch (this) {
      case CropAspectRatio.original:
        return null; // Special case
      case CropAspectRatio.free:
        return null; // Special case
      case CropAspectRatio.square:
        return 1.0;
      case CropAspectRatio.ratio3x4:
        return 3 / 4;
      case CropAspectRatio.ratio4x3:
        return 4 / 3;
      case CropAspectRatio.ratio16x9:
        return 16 / 9;
      case CropAspectRatio.ratio9x16:
        return 9 / 16;
    }
  }
}

class ImageCropperScreen extends StatefulWidget {
  final Uint8List imageData;
  final CropAspectRatio initialAspectRatio;
  final bool lockAspectRatio;

  const ImageCropperScreen({
    super.key,
    required this.imageData,
    this.initialAspectRatio = CropAspectRatio.free,
    this.lockAspectRatio = false,
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  ui.Image? _image;
  final TransformationController _transformationController =
      TransformationController();

  // State
  double _currentRotation = 0.0;
  late CropAspectRatio _selectedRatio;
  Rect _viewRect = Rect.zero; // The available space for the editor
  Rect _cropRect = Rect.zero; // The visual cut-out (relative to screen)

  // Logic
  bool _isImageLoaded = false;
  bool _isResizing = false; // Locks image pan when resizing handles
  // ignore: unused_field
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedRatio = widget.initialAspectRatio;
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(widget.imageData, (img) => completer.complete(img));
    final img = await completer.future;
    if (mounted) {
      setState(() {
        _image = img;
        _isImageLoaded = true;
      });
    }
  }

  /// Calculates the initial crop area based on image size and view constraints
  void _initializeGeometry(BoxConstraints constraints) {
    if (!_isImageLoaded || _image == null) return;
    if (_viewRect.width == constraints.maxWidth &&
        _viewRect.height == constraints.maxHeight)
      return;

    _viewRect = Offset.zero & Size(constraints.maxWidth, constraints.maxHeight);

    if (_selectedRatio != CropAspectRatio.free) {
      _onAspectRatioChanged(_selectedRatio);
    } else {
      // Default to fitting the image centered with some padding
      final double padding = 32.0;
      final double availW = constraints.maxWidth - (padding * 2);
      final double availH = constraints.maxHeight - (padding * 2);

      // Initial aspect ratio from image
      final double imgAspect = _image!.width / _image!.height;

      double initialW, initialH;
      if (availW / availH < imgAspect) {
        initialW = availW;
        initialH = initialW / imgAspect;
      } else {
        initialH = availH;
        initialW = initialH * imgAspect;
      }

      _cropRect = Rect.fromCenter(
        center: _viewRect.center,
        width: initialW,
        height: initialH,
      );

      _fitImageToCrop();
    }
  }

  /// Ensures the image covers the crop area and resets scale
  void _fitImageToCrop() {
    if (_image == null) return;

    // 1. Calculate the scale required to COVER the crop rect
    // We must handle rotation (swapping width/height if 90/270 degrees)
    final bool isRotated = (_currentRotation % math.pi).abs() > 0.1;
    final double imgW = isRotated
        ? _image!.height.toDouble()
        : _image!.width.toDouble();
    final double imgH = isRotated
        ? _image!.width.toDouble()
        : _image!.height.toDouble();

    final double scaleX = _cropRect.width / imgW;
    final double scaleY = _cropRect.height / imgH;
    final double minScale = math.max(scaleX, scaleY);

    _baseScale = minScale;

    // 2. Reset the matrix to center the image under the crop rect
    final double dx = _cropRect.center.dx - (imgW * minScale) / 2;
    final double dy = _cropRect.center.dy - (imgH * minScale) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(minScale);

    setState(() {});
  }

  void _onAspectRatioChanged(CropAspectRatio ratio) {
    if (_image == null) return;
    setState(() {
      _selectedRatio = ratio;

      // Calculate new target dimensions based on ratio
      double targetRatio;
      if (ratio == CropAspectRatio.original) {
        targetRatio = _image!.width / _image!.height;
        // If currently rotated, flip the target ratio
        if ((_currentRotation % math.pi).abs() > 0.1) {
          targetRatio = 1 / targetRatio;
        }
      } else if (ratio == CropAspectRatio.free) {
        return; // Don't change rect for free mode, just enable handles
      } else {
        targetRatio = ratio.ratio!;
      }

      // Resize _cropRect to fit within _viewRect while maintaining targetRatio
      final double padding = 32.0;
      final Rect maxRect = _viewRect.deflate(padding);

      double newW, newH;
      if (maxRect.width / maxRect.height < targetRatio) {
        newW = maxRect.width;
        newH = newW / targetRatio;
      } else {
        newH = maxRect.height;
        newW = newH * targetRatio;
      }

      _cropRect = Rect.fromCenter(
        center: maxRect.center,
        width: newW,
        height: newH,
      );

      // Re-fit image to new crop rect
      _fitImageToCrop();
    });
  }

  void _rotate() {
    setState(() {
      _currentRotation += math.pi / 2;
      // When rotating, the "Original" aspect ratio might flip orientation visually
      if (_selectedRatio == CropAspectRatio.original ||
          _selectedRatio == CropAspectRatio.free) {
        // Just fit the new orientation
      } else {
        // For fixed ratios (like square), we keep the box but fill it with rotated image
      }
      _fitImageToCrop();
    });
  }

  /// Handle dragging crop corners (Free Resize)
  void _onPanUpdate(DragUpdateDetails details) {
    if (_selectedRatio != CropAspectRatio.free) return;

    setState(() {
      _isResizing = true;

      // ignore: unused_local_variable
      double delta = details.delta.dy * -1; // Pulling up shrinks height?

      final double minSize = 100.0;
      final double newWidth = (_cropRect.width + details.delta.dx).clamp(
        minSize,
        _viewRect.width - 32,
      );
      final double newHeight = (_cropRect.height + details.delta.dy).clamp(
        minSize,
        _viewRect.height - 150,
      );

      // Center the change
      _cropRect = Rect.fromCenter(
        center: _viewRect.center,
        width: newWidth,
        height: newHeight,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isResizing = false);
    _fitImageToCrop(); // Snap image back to cover if we made crop box larger than image
  }

  Future<void> _export() async {
    if (_image == null) return;

    // 1. Calculate the crop geometry in image coordinates
    final double scale = _transformationController.value.getMaxScaleOnAxis();

    // FIX: Use the new unique name we defined in the extension
    final Offset translation = _transformationController.value
        .getTranslationOffset();

    // Convert Viewport Crop Rect to Image Coordinates
    // The image is at (translation), scaled by (scale).
    // ImageCoord = (ScreenCoord - Translation) / Scale

    final double cropX = (_cropRect.left - translation.dx) / scale;
    final double cropY = (_cropRect.top - translation.dy) / scale;
    final double cropW = _cropRect.width / scale;
    final double cropH = _cropRect.height / scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // We draw the image such that the cropped area ends up at (0,0) on the new canvas
    canvas.translate(-cropX, -cropY);

    // Apply Rotation around image center
    canvas.translate(_image!.width / 2.0, _image!.height / 2.0);
    canvas.rotate(_currentRotation);
    canvas.translate(-_image!.width / 2.0, -_image!.height / 2.0);

    canvas.drawImage(_image!, Offset.zero, Paint());

    final picture = recorder.endRecording();
    // Output size matches the crop pixel size
    final ui.Image croppedImage = await picture.toImage(
      cropW.toInt(),
      cropH.toInt(),
    );

    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (mounted) Navigator.pop(context, byteData?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImageLoaded) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Crop Image', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _export),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Initialize rects on first frame or window resize
                if (_viewRect.width != constraints.maxWidth ||
                    _viewRect.height != constraints.maxHeight) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _initializeGeometry(constraints);
                  });
                }

                return Stack(
                  children: [
                    // 1. The Image (Pan/Zoom)
                    // We disable interaction if the user is resizing the crop box handles
                    InteractiveViewer(
                      transformationController: _transformationController,
                      panEnabled: !_isResizing,
                      scaleEnabled: !_isResizing,
                      minScale: 0.1,
                      maxScale: 10.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: CustomPaint(
                          painter: _RawImagePainter(
                            image: _image!,
                            rotation: _currentRotation,
                          ),
                        ),
                      ),
                    ),

                    // 2. The Dark Overlay & Grid
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _OverlayPainter(
                          cropRect: _cropRect,
                          isResizing: _isResizing,
                        ),
                      ),
                    ),

                    // 3. Gesture Handles (Corners)
                    // Only active if "Free" mode is selected
                    if (_selectedRatio == CropAspectRatio.free)
                      Positioned.fromRect(
                        rect: _cropRect.inflate(20), // Larger hit area
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          // We use a simplified logic: dragging anywhere on the crop border triggers resize
                          // In a full app, you'd put specific Positioned widgets for corners
                          onPanStart: (d) => setState(() => _isResizing = true),
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: Container(
                            color: Colors.transparent,
                          ), // invisible hit target
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 4. Bottom Controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aspect Ratio List
          if (!widget.lockAspectRatio)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: CropAspectRatio.values.map((ratio) {
                  final isSelected = _selectedRatio == ratio;
                  return GestureDetector(
                    onTap: () => _onAspectRatioChanged(ratio),
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ratio.label,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Rotate Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _rotate,
                icon: const Icon(
                  Icons.rotate_90_degrees_cw_outlined,
                  color: Colors.white,
                ),
                tooltip: "Rotate",
              ),
              const SizedBox(width: 24),
              Text(
                "${(_currentRotation * 180 / math.pi).round() % 360}°",
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(width: 24),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentRotation = 0;
                    _onAspectRatioChanged(CropAspectRatio.original);
                  });
                },
                child: const Text(
                  "RESET",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Painters ---

/// Draws the image directly onto the canvas, handling the rotation visual
class _RawImagePainter extends CustomPainter {
  final ui.Image image;
  final double rotation;
  _RawImagePainter({required this.image, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    // We draw the image centered at (0,0) of the canvas provided by InteractiveViewer
    // Note: interactive viewer gives us a canvas where (0,0) is top left of the child.
    // We need to shift to center to rotate.

    // Actually simpler: We draw the image at (0,0) but applying rotation?
    // The InteractiveViewer moves the canvas. We just draw the image content.
    // To rotate visually:

    canvas.save();
    // Center of the image
    double cx = image.width / 2.0;
    double cy = image.height / 2.0;

    // If we want the image to rotate "in place"
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.translate(-cx, -cy);

    canvas.drawImage(image, Offset.zero, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RawImagePainter old) => old.rotation != rotation;
}

/// Draws the dark overlay, the clear cutout, the grid lines, and the corner handles
class _OverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isResizing;

  _OverlayPainter({required this.cropRect, required this.isResizing});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Darken Background
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRect(cropRect);

    // Difference (Hole)
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(overlayPath, paint);

    // 2. White Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Grid Lines (Rule of Thirds)
    if (isResizing || true) {
      // Always show grid or only when resizing?
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Vertical lines
      double dx = cropRect.width / 3;
      canvas.drawLine(
        Offset(cropRect.left + dx, cropRect.top),
        Offset(cropRect.left + dx, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + 2 * dx, cropRect.top),
        Offset(cropRect.left + 2 * dx, cropRect.bottom),
        gridPaint,
      );

      // Horizontal lines
      double dy = cropRect.height / 3;
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + dy),
        Offset(cropRect.right, cropRect.top + dy),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + 2 * dy),
        Offset(cropRect.right, cropRect.top + 2 * dy),
        gridPaint,
      );
    }

    // 4. Corner Handles (Thick corners)
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    double cornerSize = 20.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(cropRect.left, cropRect.top + cornerSize)
        ..lineTo(cropRect.left, cropRect.top)
        ..lineTo(cropRect.left + cornerSize, cropRect.top),
      handlePaint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(cropRect.right - cornerSize, cropRect.top)
        ..lineTo(cropRect.right, cropRect.top)
        ..lineTo(cropRect.right, cropRect.top + cornerSize),
      handlePaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cropRect.left, cropRect.bottom - cornerSize)
        ..lineTo(cropRect.left, cropRect.bottom)
        ..lineTo(cropRect.left + cornerSize, cropRect.bottom),
      handlePaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(cropRect.right - cornerSize, cropRect.bottom)
        ..lineTo(cropRect.right, cropRect.bottom)
        ..lineTo(cropRect.right, cropRect.bottom - cornerSize),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.cropRect != cropRect || old.isResizing != isResizing;
}

extension Matrix4Helper on Matrix4 {
  Offset getTranslationOffset() {
    // Columns 3 (index 12 and 13) hold the translation X and Y
    return Offset(storage[12], storage[13]);
  }
}
