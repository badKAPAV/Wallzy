import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  final Rect cropRect;
  OverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.7);

    // Create a path for the whole screen and subtract the crop box
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRect(cropRect);
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, paint);

    // Draw White Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(cropRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
