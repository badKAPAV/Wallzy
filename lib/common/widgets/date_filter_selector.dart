import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// -----------------------------------------------------------------------------
// 1. Navigation Control (Keep as is, it was fine)
// -----------------------------------------------------------------------------

class DateNavigationControl extends StatelessWidget {
  final int selectedYear;
  final int? selectedMonth;
  final VoidCallback onTapPill;
  final Function(int year, int? month) onDateChanged;

  const DateNavigationControl({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onTapPill,
    required this.onDateChanged,
  });

  bool get isYearMode => selectedMonth == null;

  void _handlePrevious() {
    HapticFeedback.selectionClick();
    if (isYearMode) {
      onDateChanged(selectedYear - 1, null);
    } else {
      int newMonth = selectedMonth! - 1;
      int newYear = selectedYear;
      if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      onDateChanged(newYear, newMonth);
    }
  }

  void _handleNext() {
    HapticFeedback.selectionClick();
    if (isYearMode) {
      onDateChanged(selectedYear + 1, null);
    } else {
      int newMonth = selectedMonth! + 1;
      int newYear = selectedYear;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      }
      onDateChanged(newYear, newMonth);
    }
  }

  String _getLabel() {
    if (isYearMode) return selectedYear.toString();
    const months = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${months[selectedMonth!]} $selectedYear";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _NavArrowButton(
            isLeft: true,
            icon: Icons.chevron_left_rounded,
            onTap: _handlePrevious,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CenterDatePill(
              label: _getLabel(),
              isYearMode: isYearMode,
              onTap: onTapPill,
            ),
          ),
          const SizedBox(width: 4),
          _NavArrowButton(
            isLeft: false,
            icon: Icons.chevron_right_rounded,
            onTap: _handleNext,
          ),
        ],
      ),
    );
  }
}

class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLeft;

  const _NavArrowButton({
    required this.icon,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isLeft ? 40 : 16),
        topRight: Radius.circular(isLeft ? 16 : 40),
        bottomLeft: Radius.circular(isLeft ? 40 : 16),
        bottomRight: Radius.circular(isLeft ? 16 : 40),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 40 : 16),
          topRight: Radius.circular(isLeft ? 16 : 40),
          bottomLeft: Radius.circular(isLeft ? 40 : 16),
          bottomRight: Radius.circular(isLeft ? 16 : 40),
        ),
        child: Container(
          width: 48,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CenterDatePill extends StatelessWidget {
  final String label;
  final bool isYearMode;
  final VoidCallback onTap;

  const _CenterDatePill({
    required this.label,
    required this.isYearMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha(128),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. The Modal Logic
// -----------------------------------------------------------------------------

void showDateFilterModal({
  required BuildContext context,
  required List<int> availableYears,
  required int initialYear,
  required int? initialMonth,
  required Function(int year, int? month) onApply,
  Future<Map<int, String>> Function(int year)? onStatsRequired,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    builder: (ctx) => DateFilterModal(
      availableYears: availableYears,
      initialYear: initialYear,
      initialMonth: initialMonth,
      onApply: onApply,
      onStatsRequired: onStatsRequired,
    ),
  );
}

class DateFilterModal extends StatefulWidget {
  final List<int> availableYears;
  final int initialYear;
  final int? initialMonth;
  final Function(int year, int? month) onApply;
  final Future<Map<int, String>> Function(int year)? onStatsRequired;

  const DateFilterModal({
    super.key,
    required this.availableYears,
    required this.initialYear,
    required this.initialMonth,
    required this.onApply,
    this.onStatsRequired,
  });

  @override
  State<DateFilterModal> createState() => _DateFilterModalState();
}

class _DateFilterModalState extends State<DateFilterModal> {
  late int _tempYear;
  late int? _tempMonth;
  late ScrollController _monthScrollController;

  Map<int, String> _monthlyDisplayStrings = {};
  Map<int, double> _monthlyGraphValues = {};
  double _absMaxPositive = 0.0;
  double _absMaxNegative = 0.0;
  bool _isLoading = false;

  final double _kMonthItemWidth = 44.0;
  final double _kMonthGap = 8.0;

  @override
  void initState() {
    super.initState();
    _tempYear = widget.initialYear;
    _tempMonth = widget.initialMonth;

    double initialOffset = 0;
    if (_tempMonth != null && _tempMonth! > 1) {
      initialOffset = (_tempMonth! - 2) * (_kMonthItemWidth + _kMonthGap);
      if (initialOffset < 0) initialOffset = 0;
    }
    _monthScrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    _fetchStats(_tempYear);
  }

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  double _parseValue(String input) {
    try {
      String clean = input.replaceAll(',', '');
      clean = clean.replaceAll(RegExp(r'[^0-9.kK-]'), '');
      double multiplier = 1.0;
      if (clean.toLowerCase().contains('k')) {
        multiplier = 1000.0;
        clean = clean.replaceAll(RegExp(r'[kK]'), '');
      }
      return (double.tryParse(clean) ?? 0.0) * multiplier;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _fetchStats(int year) async {
    if (widget.onStatsRequired == null) return;

    setState(() {
      _isLoading = true;
      // We do NOT clear data here. Keeping old data during loading prevents flickering.
    });

    try {
      final rawStats = await widget.onStatsRequired!(year);

      if (!mounted || _tempYear != year) return;

      final values = <int, double>{};
      final displayStrings = <int, String>{};
      double maxPos = 0.0;
      double maxNeg = 0.0;

      bool isZeroBased = rawStats.keys.contains(0);

      rawStats.forEach((k, v) {
        int uiKey = isZeroBased ? k + 1 : k;
        if (uiKey < 1 || uiKey > 12) return;

        final parsed = _parseValue(v);
        values[uiKey] = parsed;
        displayStrings[uiKey] = v;

        if (parsed > 0 && parsed > maxPos) maxPos = parsed;
        if (parsed < 0 && parsed.abs() > maxNeg) maxNeg = parsed.abs();
      });

      setState(() {
        _monthlyDisplayStrings = displayStrings;
        _monthlyGraphValues = values;
        _absMaxPositive = maxPos;
        _absMaxNegative = maxNeg;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = widget.availableYears.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    if (years.isEmpty) years.add(DateTime.now().year);

    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        // crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Machine',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    visualDensity: VisualDensity.comfortable,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    widget.onApply(_tempYear, _tempMonth);
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          // Graph Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Constants
                const double labelZoneHeight = 32.0;

                // Determine target heights
                final double totalMagnitude = _absMaxPositive + _absMaxNegative;
                final double positiveRatio = totalMagnitude == 0
                    ? 0.5
                    : _absMaxPositive / totalMagnitude;

                return _isLoading && _monthlyGraphValues.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _monthlyGraphValues.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.separated(
                        controller: _monthScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: 12,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: _kMonthGap),
                        itemBuilder: (context, index) {
                          final monthIndex = index + 1;
                          final rawValue =
                              _monthlyGraphValues[monthIndex] ?? 0.0;

                          return SizedBox(
                            key: ValueKey("item_$monthIndex"), // Stable key
                            width: _kMonthItemWidth,
                            child: _SplitAxisGraphItem(
                              label: _getMonthAbbr(monthIndex),
                              displayValue: _monthlyDisplayStrings[monthIndex],
                              value: rawValue,
                              maxPositiveGlobal: _absMaxPositive,
                              maxNegativeGlobal: _absMaxNegative,
                              // We pass the ratio and total height, let item animate
                              parentConstraints: constraints,
                              positiveRatio: positiveRatio,
                              labelZoneHeight: labelZoneHeight,
                              isSelected: _tempMonth == monthIndex,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _tempMonth = (_tempMonth == monthIndex)
                                      ? null
                                      : monthIndex;
                                });
                              },
                            ),
                          );
                        },
                      );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Year Selector
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                padding: const EdgeInsets.only(right: 24),
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == _tempYear;

                  return GestureDetector(
                    onTap: () {
                      if (_tempYear != year) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _tempYear = year;
                          _tempMonth = null;
                        });
                        _fetchStats(year);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,

                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        year.toString(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            "No data for $_tempYear",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthAbbr(int index) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (index < 1 || index > 12) return '';
    return months[index - 1];
  }
}

// -----------------------------------------------------------------------------
// 3. The Graph Item (Optimized for performance and stability)
// -----------------------------------------------------------------------------

class _SplitAxisGraphItem extends StatelessWidget {
  final String label;
  final String? displayValue;
  final double value;
  final double maxPositiveGlobal;
  final double maxNegativeGlobal;
  final BoxConstraints parentConstraints;
  final double positiveRatio;
  final double labelZoneHeight;
  final bool isSelected;
  final VoidCallback onTap;

  const _SplitAxisGraphItem({
    required this.label,
    required this.displayValue,
    required this.value,
    required this.maxPositiveGlobal,
    required this.maxNegativeGlobal,
    required this.parentConstraints,
    required this.positiveRatio,
    required this.labelZoneHeight,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = value >= 0;

    // --- Height Calculation ---
    const double tooltipReserve = 32.0;

    final double posAvailable =
        (parentConstraints.maxHeight - labelZoneHeight) * positiveRatio;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // 1. TOP ZONE (Positive)
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            height: posAvailable,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double drawAvailable =
                    (constraints.maxHeight - tooltipReserve).clamp(
                      0.0,
                      double.infinity,
                    );

                double barHeight = 0;
                if (isPositive && maxPositiveGlobal > 0 && drawAvailable > 0) {
                  barHeight = (value / maxPositiveGlobal) * drawAvailable;
                }
                if (isPositive && value != 0 && barHeight < 6) barHeight = 6;

                return Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Tooltip (Always present in tree if data exists, animates visual state)
                    if (isPositive && value != 0 && displayValue != null)
                      Positioned(
                        bottom: barHeight + 8,
                        child: _GraphTooltip(
                          key: ValueKey("tooltip_pos_$label"),
                          label: displayValue!,
                          theme: theme,
                          isHighlighted: isSelected,
                        ),
                      ),

                    // Bar
                    AnimatedContainer(
                      key: ValueKey("bar_pos_$label"),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      width: 24,
                      height: isPositive ? barHeight : 0,
                      decoration: BoxDecoration(
                        // Always use a gradient for smooth interpolation
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isSelected
                              ? [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ]
                              : [
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. MIDDLE ZONE (Label/Divider)
          Container(
            height: labelZoneHeight,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 10 : 0,
                      vertical: isSelected ? 4 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. BOTTOM ZONE (Negative)
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            // Calculate available height for negative zone similar to positive
            height:
                (parentConstraints.maxHeight - labelZoneHeight) *
                (1.0 - positiveRatio),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double drawAvailable =
                    (constraints.maxHeight - tooltipReserve).clamp(
                      0.0,
                      double.infinity,
                    );

                double barHeight = 0;
                if (!isPositive && maxNegativeGlobal > 0 && drawAvailable > 0) {
                  barHeight = (value.abs() / maxNegativeGlobal) * drawAvailable;
                }
                if (!isPositive && value != 0 && barHeight < 6) barHeight = 6;

                return Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    if (!isPositive && value != 0 && displayValue != null)
                      Positioned(
                        top: barHeight + 8,
                        child: _GraphTooltip(
                          key: ValueKey("tooltip_neg_$label"),
                          label: displayValue!,
                          theme: theme,
                          isHighlighted: isSelected,
                        ),
                      ),

                    AnimatedContainer(
                      key: ValueKey("bar_neg_$label"),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      width: 24,
                      height: (!isPositive) ? barHeight : 0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isSelected
                              ? [
                                  theme.colorScheme.error,
                                  theme.colorScheme.error.withValues(
                                    alpha: 0.7,
                                  ),
                                ]
                              : [
                                  theme.colorScheme.error.withValues(
                                    alpha: 0.3,
                                  ),
                                  theme.colorScheme.error.withValues(
                                    alpha: 0.3,
                                  ),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphTooltip extends StatelessWidget {
  final String label;
  final ThemeData theme;
  final bool isHighlighted;

  const _GraphTooltip({
    super.key,
    required this.label,
    required this.theme,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(
          "Tooltip_${label}_$isHighlighted",
        ), // Ensure rebuild for style change
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlighted
              ? theme.colorScheme.inverseSurface
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isHighlighted
                ? theme.colorScheme.onInverseSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}
