import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CropperPainter extends CustomPainter {
  final ui.Image image;
  final Matrix4 transform;
  final Size cropSize;

  CropperPainter({
    required this.image,
    required this.transform,
    required this.cropSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final cropRect = Rect.fromCenter(
      center: center,
      width: cropSize.width,
      height: cropSize.height,
    );

    // 1. Draw transformed image
    canvas.save();
    // We want the transformation to happen relative to the crop area center
    canvas.translate(center.dx, center.dy);
    canvas.transform(transform.storage);
    canvas.translate(-center.dx, -center.dy);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.contain,
    );
    canvas.restore();

    // 2. Draw Dark Overlay with Cutout
    final paint = Paint()..color = Colors.black.withOpacity(0.7);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRect(cropRect);
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(overlayPath, paint);

    // 3. Draw Crop Border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
