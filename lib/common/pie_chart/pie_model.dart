import 'package:flutter/material.dart';

class PieData {
  final double value;
  final Color color;
  final Gradient? gradient;

  const PieData({required this.value, this.color = Colors.grey, this.gradient});
}
