import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';

enum Timeframe { weeks, months, years }

class _PeriodSummary {
  final String label;
  final String fullDateLabel;
  final double income;
  final double expense;
  final DateTimeRange range;

  _PeriodSummary({
    required this.label,
    required this.fullDateLabel,
    required this.income,
    required this.expense,
    required this.range,
  });
}

class AnalyticsWidget extends StatefulWidget {
  final Timeframe selectedTimeframe;
  final ValueChanged<Timeframe> onTimeframeChanged;

  const AnalyticsWidget({
    super.key,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
  });

  @override
  State<AnalyticsWidget> createState() => _AnalyticsWidgetState();
}

class _AnalyticsWidgetState extends State<AnalyticsWidget> {
  int? _selectedIndex;

  // Cache max values for stable animation
  double _absMaxPositive = 1.0;
  double _absMaxNegative = 1.0;
  List<_PeriodSummary> _summaries = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateSummaries();
  }

  @override
  void didUpdateWidget(covariant AnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimeframe != widget.selectedTimeframe) {
      _selectedIndex = null; // Reset before recalculating
      _calculateSummaries();
    }
  }

  void _calculateSummaries() {
    final txProvider = Provider.of<TransactionProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final now = DateTime.now();

    List<_PeriodSummary> newSummaries = [];
    double maxPos = 0;
    double maxNeg = 0;

    // Show 6 bars for good density
    int barCount = 6;

    for (int i = barCount - 1; i >= 0; i--) {
      DateTimeRange range;
      String label;
      String fullLabel;

      switch (widget.selectedTimeframe) {
        case Timeframe.weeks:
          final startDay = now.subtract(
            Duration(days: now.weekday - 1 + (i * 7)),
          );
          range = DateTimeRange(
            start: DateTime(startDay.year, startDay.month, startDay.day),
            end: startDay.add(const Duration(days: 7)),
          );
          label = DateFormat('d MMM').format(startDay);
          fullLabel =
              "${DateFormat('d MMM').format(startDay)} - ${DateFormat('d MMM').format(range.end.subtract(const Duration(days: 1)))}";
          break;

        case Timeframe.months:
          var targetMonth = now.month - i;
          var targetYear = now.year;
          while (targetMonth <= 0) {
            targetMonth += 12;
            targetYear--;
          }
          range = BudgetCycleHelper.getCycleRange(
            targetMonth: targetMonth,
            targetYear: targetYear,
            mode: settings.budgetCycleMode,
            startDay: settings.budgetCycleStartDay,
          );
          final mid = range.start.add(const Duration(days: 15));
          label = DateFormat('MMM').format(mid);
          fullLabel = DateFormat('MMMM yyyy').format(mid);
          break;

        case Timeframe.years:
          final year = DateTime(now.year - i, 1, 1);
          range = DateTimeRange(
            start: year,
            end: DateTime(year.year + 1, 1, 1),
          );
          label = DateFormat('yy').format(year);
          fullLabel = DateFormat('yyyy').format(year);
          break;
      }

      final income = txProvider.getTotal(
        start: range.start,
        end: range.end,
        type: 'income',
      );
      final expense = txProvider.getTotal(
        start: range.start,
        end: range.end,
        type: 'expense',
      );

      if (income > maxPos) maxPos = income;
      if (expense > maxNeg) maxNeg = expense;

      newSummaries.add(
        _PeriodSummary(
          label: label,
          fullDateLabel: fullLabel,
          income: income,
          expense: expense,
          range: range,
        ),
      );
    }

    setState(() {
      _summaries = newSummaries;
      _absMaxPositive = maxPos > 0 ? maxPos : 1.0;
      _absMaxNegative = maxNeg > 0 ? maxNeg : 1.0;
      _selectedIndex ??= _summaries.length - 1;
    });
  }

  // String _formatCurrency(double value, String symbol) {
  //   if (value >= 1000) {
  //     return NumberFormat.compactCurrency(symbol: symbol).format(value);
  //   }
  //   return NumberFormat.currency(
  //     symbol: symbol,
  //     decimalDigits: 0,
  //   ).format(value);
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final currencySymbol = settings.currencySymbol;
    final appColors = theme.extension<AppColors>()!;

    final selectedData =
        (_selectedIndex != null && _selectedIndex! < _summaries.length)
        ? _summaries[_selectedIndex!]
        : _summaries.last;

    return Container(
      clipBehavior: Clip.none, // Allow timeframe pill to float safely
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Header Title
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTransactionsScreen(),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Cash Flow",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                          fontFamily: 'momo',
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 10),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCoins01,
                        color: theme.colorScheme.primary,
                        size: 22,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _StatColumn(
                      currencySymbol: currencySymbol,
                      label: "In",
                      amount: selectedData.income,
                      color: appColors.income,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatColumn(
                      currencySymbol: currencySymbol,
                      label: "Out",
                      amount: selectedData.expense,
                      color: appColors.expense,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // The Graph Area
              SizedBox(
                height: 140,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalMagnitude =
                        _absMaxPositive + _absMaxNegative;
                    final double positiveRatio = totalMagnitude == 0
                        ? 0.5
                        : _absMaxPositive / totalMagnitude;

                    // Fixed height for the month label divider
                    const double labelHeight = 24.0;

                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.5, end: positiveRatio),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedRatio, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _summaries.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final isSelected = _selectedIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                                child: _GraphBar(
                                  data: data,
                                  isSelected: isSelected,
                                  parentHeight: constraints.maxHeight,
                                  positiveRatio: animatedRatio,
                                  maxPositive: _absMaxPositive,
                                  maxNegative: _absMaxNegative,
                                  labelHeight: labelHeight,
                                  theme: theme,
                                  appColors: appColors,
                                  currencySymbol: currencySymbol,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // The Original Timeframe Pill
          Positioned(
            top: 0,
            right: 0,
            child: _TimeframePill(
              selected: widget.selectedTimeframe,
              onChanged: widget.onTimeframeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// --- SUB WIDGETS ---

class _StatColumn extends StatelessWidget {
  final String currencySymbol;
  final String label;
  final double amount;
  final Color color;

  const _StatColumn({
    required this.currencySymbol,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = label.toLowerCase().contains('in');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                NumberFormat.compactCurrency(
                  symbol: currencySymbol,
                ).format(amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- THE ROBUST GRAPH BAR (Ported from Date Filter) ---

class _GraphBar extends StatelessWidget {
  final _PeriodSummary data;
  final bool isSelected;
  final double parentHeight;
  final double positiveRatio;
  final double maxPositive;
  final double maxNegative;
  final double labelHeight;
  final ThemeData theme;
  final AppColors appColors;
  final String currencySymbol;

  const _GraphBar({
    required this.data,
    required this.isSelected,
    required this.parentHeight,
    required this.positiveRatio,
    required this.maxPositive,
    required this.maxNegative,
    required this.labelHeight,
    required this.theme,
    required this.appColors,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Zone Heights
    // We reserve space for the label (24) so it's not part of the bar calculation
    final double graphHeight = parentHeight - labelHeight;
    final double posZoneHeight = graphHeight * positiveRatio;

    // !!! IMPORTANT: Tooltip Reserve !!!
    // We subtract this from the AVAILABLE draw space inside the layout builder
    // to ensure the bar never touches the edge, leaving room for the tooltip.
    const double tooltipReserve = 0.0;

    return Column(
      children: [
        // --- POSITIVE ZONE (Grows Up) ---
        SizedBox(
          height: posZoneHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The max height the bar can ACTUALLY take
              final double drawAvailable =
                  (constraints.maxHeight - tooltipReserve).clamp(
                    0.0,
                    double.infinity,
                  );

              double barHeight = 0;
              if (maxPositive > 0 && drawAvailable > 0) {
                barHeight = (data.income / maxPositive) * drawAvailable;
              }
              // Min visibility
              if (data.income > 0 && barHeight < 6) barHeight = 6;

              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none, // Allows tooltip to bleed horizontally
                children: [
                  // Tooltip
                  // if (isSelected && data.income > 0)
                  //   Positioned(
                  //     bottom: barHeight + 6, // Sit on top of bar
                  //     child: _GraphTooltip(
                  //       label: _formatMini(data.income),
                  //       theme: theme,
                  //       isHighlighted: true,
                  //       color: appColors.income,
                  //     ),
                  //   ),

                  // Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    width: 12,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? appColors.income
                          : appColors.income.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // --- AXIS LABEL ---
        SizedBox(
          height: labelHeight,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dashed Line
                Container(
                  height: 1,
                  width: double.infinity,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                ),
                // Pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 8 : 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- NEGATIVE ZONE (Grows Down) ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The max height the bar can ACTUALLY take
              final double drawAvailable =
                  (constraints.maxHeight - tooltipReserve).clamp(
                    0.0,
                    double.infinity,
                  );

              double barHeight = 0;
              if (maxNegative > 0 && drawAvailable > 0) {
                barHeight = (data.expense / maxNegative) * drawAvailable;
              }
              if (data.expense > 0 && barHeight < 6) barHeight = 6;

              return Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none, // Allows tooltip to bleed
                children: [
                  // Tooltip
                  // if (isSelected && data.expense > 0)
                  //   Positioned(
                  //     top: barHeight + 6, // Sit below bar
                  //     child: _GraphTooltip(
                  //       label: _formatMini(data.expense),
                  //       theme: theme,
                  //       isHighlighted: true,
                  //       color: appColors.expense,
                  //     ),
                  //   ),

                  // Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    width: 12,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? appColors.expense
                          : appColors.expense.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- ORIGINAL TIMEFRAME PILL ---

class _TimeframePill extends StatefulWidget {
  final Timeframe selected;
  final Function(Timeframe) onChanged;

  const _TimeframePill({required this.selected, required this.onChanged});

  @override
  State<_TimeframePill> createState() => _TimeframePillState();
}

class _TimeframePillState extends State<_TimeframePill> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedText =
        widget.selected.name[0].toUpperCase() +
        widget.selected.name.substring(1);

    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isExpanded ? 0.1 : 0.05),
          blurRadius: _isExpanded ? 12 : 4,
          offset: Offset(0, _isExpanded ? 6 : 2),
        ),
      ],
    );

    return TapRegion(
      onTapOutside: (event) {
        if (_isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isExpanded = !_isExpanded);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            alignment: Alignment.topRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isExpanded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                if (_isExpanded)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: Timeframe.values.map((tf) {
                      final isSelected = widget.selected == tf;
                      final text =
                          tf.name[0].toUpperCase() + tf.name.substring(1);

                      return GestureDetector(
                        onTap: () {
                          widget.onChanged(tf);
                          HapticFeedback.lightImpact();
                          setState(() => _isExpanded = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          color: Colors.transparent,
                          child: Text(
                            text,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
