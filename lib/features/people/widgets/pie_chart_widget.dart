import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PeoplePieChart extends StatelessWidget {
  final double youOwe;
  final double owesYou;

  const PeoplePieChart({super.key, required this.youOwe, required this.owesYou});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.red,
            value: youOwe,
            title: 'You Owe',
            radius: 50,
            titleStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: Colors.green,
            value: owesYou,
            title: 'Owes You',
            radius: 50,
            titleStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
        centerSpaceRadius: 40,
      ),
    );
  }
}