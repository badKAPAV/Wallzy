import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';

class RobustPiePainter extends CustomPainter {
  final List<PieData> sections;
  final double width;
  final double animationValue;
  final Color emptyColor;
  final double gapDegrees;

  RobustPiePainter({
    required this.sections,
    required this.width,
    required this.animationValue,
    required this.emptyColor,
    required this.gapDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - width) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double total = 0.0;
    for (PieData s in sections) total += s.value;

    // 1. Empty State
    if (total <= 0 || sections.isEmpty) {
      final paint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // 2. Full Circle Logic (100% Logic)
    // FIX: Removed "&& gapDegrees == 0".
    // Now, if one item is > 99.9%, we ALWAYS draw a seamless circle, ignoring the gap.
    bool isFullCircle =
        (sections.length == 1 ||
        sections.any((PieData s) => s.value / total > 0.999));

    if (isFullCircle) {
      final dominant = sections.firstWhere(
        (PieData s) => s.value / total > 0.999,
        orElse: () => sections[0],
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt; // Seamless join for full circle

      if (dominant.gradient != null) {
        paint.shader = dominant.gradient!.createShader(rect);
      } else {
        paint.color = dominant.color;
      }

      // Draw full animated ring (0 to 360)
      canvas.drawArc(rect, -pi / 2, 2 * pi * animationValue, false, paint);
      return;
    }

    // 3. Gap Math (Only runs if we have multiple visible sections)
    double gapRadians = gapDegrees * (pi / 180);

    // Count visible items to calculate total gap space
    int visibleCount = sections.where((PieData s) => s.value > 0).length;

    // Safety check: If visible items < 2, gaps don't make sense logically,
    // but the isFullCircle check above usually catches this.
    // This is a fallback for edge cases like [50%, 0%, 0%] which is technically 100% but might fail the .any() check if floating point math is weird.
    if (visibleCount < 2) gapRadians = 0;

    double totalGapSpace = visibleCount * gapRadians;
    double availableSpace = (2 * pi) - totalGapSpace;

    // Prevent negative space if gaps are too huge
    if (availableSpace <= 0) {
      availableSpace = 2 * pi;
      gapRadians = 0;
    }

    double startAngle = -pi / 2;

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final percent = section.value / total;

      if (percent <= 0) continue;

      // Distribute available space (360 - gaps)
      final sweepAngle = (percent * availableSpace) * animationValue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      if (section.gradient != null) {
        paint.shader = section.gradient!.createShader(rect);
      } else {
        paint.color = section.color;
      }

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      // Move start pointer by (Slice + Gap)
      startAngle += sweepAngle + (gapRadians * animationValue);
    }
  }

  @override
  bool shouldRepaint(covariant RobustPiePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.gapDegrees != gapDegrees ||
        oldDelegate.sections != sections;
  }
}
