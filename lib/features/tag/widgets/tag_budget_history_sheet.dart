import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/budget_helper.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';

class TagBudgetHistorySheet extends StatelessWidget {
  final Tag tag;

  const TagBudgetHistorySheet({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);

    // 1. Validation for recurring budget
    if (tag.tagBudgetFrequency == null ||
        tag.tagBudgetFrequency == TagBudgetResetFrequency.never) {
      return Container(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle for consistency even in small sheet
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendarRemove02,
              color: Theme.of(context).colorScheme.outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "No History Available",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "History is only tracked for recurring budgets (Weekly, Monthly, etc).",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    // 2. Calculation
    final history = _calculateHistory(tag, txProvider.transactions, settings);

    // 3. Return Draggable Sheet if we have a recurring budget
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Reverse for chart (Oldest -> Newest)
        final chartData = history.take(6).toList().reversed.toList();

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Budget History",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Past ${_getFreqLabel(tag.tagBudgetFrequency)} Performance",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAnalytics01,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // The Chart
                    if (chartData.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AspectRatio(
                          aspectRatio: 2.0,
                          child: _BudgetTrendChart(
                            data: chartData,
                            tagColor: tag.color != null
                                ? Color(tag.color!)
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "DETAILS",
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.outline,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // The List
                    ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        0,
                        0,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _HistoryItemTile(
                          item: history[index],
                          currency: settings.currencySymbol,
                          tagColor: tag.color != null
                              ? Color(tag.color!)
                              : theme.colorScheme.primary,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFreqLabel(TagBudgetResetFrequency? freq) {
    if (freq == null) return '';
    final str = freq.toString().split('.').last;
    return str[0].toUpperCase() + str.substring(1);
  }

  List<_HistoryItem> _calculateHistory(
    Tag tag,
    List<TransactionModel> transactions,
    SettingsProvider settings,
  ) {
    final List<_HistoryItem> items = [];
    final frequency = tag.tagBudgetFrequency!;
    final now = DateTime.now();

    // Iterate back 12 periods
    for (int i = 0; i < 12; i++) {
      DateTime periodStart;
      DateTime periodEnd;
      String label;
      String shortLabel; // For chart x-axis

      if (frequency == TagBudgetResetFrequency.monthly) {
        final cycle = BudgetCycleHelper.getCycleRange(
          targetYear: now.year,
          targetMonth: now.month - i,
          startDay: settings.budgetCycleStartDay,
          mode: settings.budgetCycleMode,
        );
        periodStart = cycle.start;
        periodEnd = cycle.end;
        label = DateFormat('MMMM yyyy').format(periodStart);
        shortLabel = DateFormat('MMM').format(periodStart);
      } else if (frequency == TagBudgetResetFrequency.weekly) {
        final startOfWeek = now
            .subtract(Duration(days: now.weekday - 1))
            .subtract(Duration(days: 7 * i));
        periodStart = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        periodEnd = periodStart.add(
          const Duration(days: 6, hours: 23, minutes: 59),
        );

        final endFmt = DateFormat('d').format(periodEnd);
        label = "${DateFormat('MMM d').format(periodStart)} - $endFmt";
        shortLabel = "${periodStart.day}-$endFmt";
      } else if (frequency == TagBudgetResetFrequency.yearly) {
        final y = now.year - i;
        periodStart = DateTime(y, 1, 1);
        periodEnd = DateTime(y, 12, 31, 23, 59);
        label = "$y";
        shortLabel = "'${y.toString().substring(2)}";
      } else {
        continue;
      }

      final netSpent = BudgetHelper.calculateNetSpentForRange(
        tag,
        transactions,
        periodStart,
        periodEnd,
      );

      // Skip future dates if no spend
      if (periodStart.isAfter(now) && netSpent == 0) continue;

      items.add(
        _HistoryItem(
          label: label,
          shortLabel: shortLabel,
          netSpent: netSpent,
          budget: tag.tagBudget ?? 0,
          periodStart: periodStart,
        ),
      );
    }
    return items;
  }
}

// --- MODELS ---

class _HistoryItem {
  final String label;
  final String shortLabel;
  final double netSpent;
  final double budget;
  final DateTime periodStart;

  _HistoryItem({
    required this.label,
    required this.shortLabel,
    required this.netSpent,
    required this.budget,
    required this.periodStart,
  });

  double get remaining => budget - netSpent;
  bool get isOverspent => netSpent > budget;
  double get percentage => budget == 0
      ? 0
      : (netSpent / budget).clamp(0.0, 1.5); // Cap at 150% for graph
}

// --- WIDGETS ---

class _BudgetTrendChart extends StatelessWidget {
  final List<_HistoryItem> data;
  final Color tagColor;

  const _BudgetTrendChart({required this.data, required this.tagColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Find max value to scale chart comfortably
    double maxY = data
        .map((e) => e.budget > e.netSpent ? e.budget : e.netSpent)
        .reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.1, // Add 10% headroom
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => theme.colorScheme.inverseSurface,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = data[groupIndex];
              return BarTooltipItem(
                "${(item.netSpent / item.budget * 100).toInt()}%",
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    data[index].shortLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isOver = item.isOverspent;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.netSpent,
                color: isOver ? theme.colorScheme.error : tagColor,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: item.budget, // Background shows the Budget Limit
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryItemTile extends StatelessWidget {
  final _HistoryItem item;
  final String currency;
  final Color tagColor;

  const _HistoryItemTile({
    required this.item,
    required this.currency,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = item.isOverspent;
    final pct = (item.netSpent / item.budget).clamp(0.0, 1.0);

    final numberFmt = NumberFormat.compactCurrency(symbol: currency);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: isOver
            ? Border.all(color: theme.colorScheme.error.withOpacity(0.3))
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 1. Icon Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOver
                      ? theme.colorScheme.errorContainer
                      : tagColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: isOver
                      ? HugeIcons.strokeRoundedAlert02
                      : HugeIcons.strokeRoundedTick02,
                  color: isOver ? theme.colorScheme.error : tagColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),

              // 2. Date Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isOver
                          ? "Exceeded by ${numberFmt.format(item.netSpent - item.budget)}"
                          : "Saved ${numberFmt.format(item.remaining)}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isOver
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Amount Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    numberFmt.format(item.netSpent),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOver
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "of ${numberFmt.format(item.budget)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. Progress Line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: theme.colorScheme.surfaceDim,
              color: isOver ? theme.colorScheme.error : tagColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
