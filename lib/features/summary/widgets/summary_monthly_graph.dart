import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

class DailyExpenseGraph extends StatefulWidget {
  final List<TransactionModel> transactions;
  final DateTime monthDate;
  final Color? lineColor;

  const DailyExpenseGraph({
    super.key,
    required this.transactions,
    required this.monthDate,
    this.lineColor,
  });

  @override
  State<DailyExpenseGraph> createState() => _DailyExpenseGraphState();
}

class _DailyExpenseGraphState extends State<DailyExpenseGraph> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.lineColor ?? theme.colorScheme.primary;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    // 1. Process Data
    final daysInMonth = DateUtils.getDaysInMonth(
      widget.monthDate.year,
      widget.monthDate.month,
    );
    final Map<int, double> dailyTotals = {};

    for (int i = 1; i <= daysInMonth; i++) {
      dailyTotals[i] = 0.0;
    }

    for (var tx in widget.transactions) {
      if (tx.type == 'expense') {
        final day = tx.timestamp.day;
        dailyTotals[day] = (dailyTotals[day] ?? 0) + tx.amount;
      }
    }

    final List<FlSpot> spots = [];
    double maxAmount = 0;

    dailyTotals.forEach((day, amount) {
      if (amount > maxAmount) maxAmount = amount;
      spots.add(FlSpot(day.toDouble(), amount));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Expense Trend",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      DateFormat('MMMM yyyy').format(widget.monthDate),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AspectRatio(
                aspectRatio: 1.80,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxAmount > 0 ? maxAmount / 2 : 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.2,
                          ),
                          strokeWidth: 0.5,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval:
                              1, // Set to 1 to have full control in getTitlesWidget
                          getTitlesWidget: (value, meta) {
                            final int day = value.toInt();
                            // Logic to show Day 1, 10, 20, and the last day
                            // We avoid showing Day 20 if the last day is very close (e.g. 23)
                            // But usually for months (28-31), 20 and last are fine.
                            bool shouldShow = false;
                            if (day == 1) shouldShow = true;
                            if (day == 10) shouldShow = true;
                            if (day == 20) shouldShow = true;
                            if (day == daysInMonth) shouldShow = true;

                            // Collision prevention: If we are showing the last day,
                            // make sure the previous label isn't too close.
                            if (day == 20 && (daysInMonth - day) < 5) {
                              shouldShow = false;
                            }

                            if (!shouldShow) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                'Day $day',
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxAmount > 0 ? maxAmount / 2 : 1,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text(
                              NumberFormat.compact().format(value),
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 1,
                    maxX: daysInMonth.toDouble(),
                    minY: 0,
                    maxY: maxAmount * 1.2,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => theme.colorScheme.surface,
                        tooltipBorderRadius: BorderRadius.circular(12),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tooltipBorder: BorderSide(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            return LineTooltipItem(
                              'DAY ${barSpot.x.toInt()}\n',
                              TextStyle(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                fontSize: 9,
                              ),
                              children: [
                                TextSpan(
                                  text: NumberFormat.currency(
                                    symbol: currencySymbol,
                                    decimalDigits: 0,
                                  ).format(barSpot.y),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                      getTouchedSpotIndicator:
                          (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: color.withOpacity(0.3),
                                  strokeWidth: 2,
                                  dashArray: [5, 5],
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 6,
                                          color: color,
                                          strokeWidth: 3,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                ),
                              );
                            }).toList();
                          },
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        preventCurveOverShooting: true,
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.2),
                              color.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 600.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutQuart,
        );
  }
}
