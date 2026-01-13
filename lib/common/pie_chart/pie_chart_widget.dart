import 'package:flutter/material.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/common/pie_chart/pie_painter.dart';

class LedgrPieChart extends StatefulWidget {
  final List<PieData> sections;
  final double thickness;
  final Color emptyColor;
  final double gap; // ✨ NEW: Gap in degrees

  const LedgrPieChart({
    super.key,
    required this.sections,
    this.thickness = 16.0,
    this.gap = 0.0, // Defaults to 0 (No gap)
    this.emptyColor = const Color(0xFFF0F0F0),
  });

  @override
  State<LedgrPieChart> createState() => _LedgrPieChartState();
}

class _LedgrPieChartState extends State<LedgrPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(LedgrPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections != oldWidget.sections || widget.gap != oldWidget.gap) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: RobustPiePainter(
            sections: widget.sections,
            width: widget.thickness,
            gapDegrees: widget.gap, // Pass the gap
            animationValue: _animation.value,
            emptyColor: widget.emptyColor,
          ),
        );
      },
    );
  }
}
