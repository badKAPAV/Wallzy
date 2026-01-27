import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SummaryPieChart extends StatefulWidget {
  final Map<String, double> categoryAmounts;
  final double totalAmount;
  final String currencySymbol;

  const SummaryPieChart({
    super.key,
    required this.categoryAmounts,
    required this.totalAmount,
    required this.currencySymbol,
  });

  @override
  State<SummaryPieChart> createState() => _SummaryPieChartState();
}

class _SummaryPieChartState extends State<SummaryPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categoryAmounts.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Prepare data
    final sortedEntries = widget.categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // We only show top 6 specific slices to keep chart clean
    final topEntries = sortedEntries.take(6).toList();

    // Determine Center Text
    String centerLabel = 'Total Spent';
    String centerValue =
        '${widget.currencySymbol}${NumberFormat('#,##0').format(widget.totalAmount)}';

    if (touchedIndex != -1 && touchedIndex < topEntries.length) {
      final entry = topEntries[touchedIndex];
      centerLabel = entry.key; // Category Name
      centerValue =
          '${widget.currencySymbol}${NumberFormat('#,##0').format(entry.value)}';
    }

    // Key values for the chart
    const double centerRadius = 85.0;
    const double sectionThickness = 28.0;
    const double touchedThickness = 38.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 4, // Clean separation
            centerSpaceRadius: centerRadius, // Donut style
            sections: _buildSections(
              topEntries,
              sectionThickness,
              touchedThickness,
            ),
            startDegreeOffset: 270,
          ),
        ),

        // The Interactive Center
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: centerRadius * 2 - 10,
          height: centerRadius * 2 - 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                centerValue,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
    double radius,
    double touchedRadius,
  ) {
    return List.generate(entries.length, (i) {
      final isTouched = i == touchedIndex;
      final entry = entries[i];
      final color =
          Colors.primaries[entry.key.hashCode % Colors.primaries.length];

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '', // We hide titles on the chart itself for a cleaner look
        radius: isTouched ? touchedRadius : radius,
        badgeWidget: isTouched ? _buildBadge(entry.key, color) : null,
        badgePositionPercentageOffset: 1.4,
        borderSide: BorderSide(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      );
    });
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
  }
}
