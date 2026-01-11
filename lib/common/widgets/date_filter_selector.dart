import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// A complete navigation row with [ < ] [ Date Pill ] [ > ]
class DateNavigationControl extends StatelessWidget {
  final int selectedYear;
  final int? selectedMonth; // If null, we are in "Year Mode"
  final VoidCallback onTapPill; // Opens the modal
  final Function(int year, int? month) onDateChanged; // Handles Next/Prev logic

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
      // Year Mode: Go back 1 year
      onDateChanged(selectedYear - 1, null);
    } else {
      // Month Mode: Go back 1 month (Handle Jan -> Dec rollover)
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
      // Year Mode: Go forward 1 year
      onDateChanged(selectedYear + 1, null);
    } else {
      // Month Mode: Go forward 1 month (Handle Dec -> Jan rollover)
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
    if (isYearMode) {
      return selectedYear.toString();
    }
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
          // Left Arrow
          _NavArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: _handlePrevious,
          ),

          const SizedBox(width: 8),

          // Middle Pill (Opens Modal)
          Expanded(
            child: _CenterDatePill(
              label: _getLabel(),
              isYearMode: isYearMode,
              onTap: onTapPill,
            ),
          ),

          const SizedBox(width: 8),

          // Right Arrow
          _NavArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: _handleNext,
          ),
        ],
      ),
    );
  }
}

/// Helper: The small square arrow buttons
class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(50), // Slightly rounded square
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 48,
          height: 48,
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

/// Helper: The middle pill (Similar to your original DateFilterPill)
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
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 48, // Match height of arrow buttons
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                // Change icon based on mode for nice polish
                icon: isYearMode
                    ? HugeIcons
                          .strokeRoundedCalendar01 // Year icon
                    : HugeIcons.strokeRoundedCalendar04, // Month icon
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
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
    showDragHandle: true,
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
  double _maxGraphValue = 1.0;
  bool _isLoading = false;

  final double _kMonthItemWidth = 48.0;
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
      // 1. Remove commas (common in 1,200.00) to avoid parsing errors
      //    But keep dots for decimals.
      String clean = input.replaceAll(',', '');

      // 2. Extract numeric parts and K/k suffix
      clean = clean.replaceAll(
        RegExp(r'[^0-9.kK-]'),
        '',
      ); // Added '-' for negative values

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
      // We don't clear immediate data if we want to show it while loading the next year
      // but the user's request suggests they saw "No data" which means it cleared.
      // Let's clear so we don't show wrong data for the new year.
      _monthlyDisplayStrings = {};
      _monthlyGraphValues = {};
    });

    try {
      final rawStats = await widget.onStatsRequired!(year);

      // Race Condition Guard:
      if (!mounted || _tempYear != year) return;

      final values = <int, double>{};
      final displayStrings = <int, String>{};
      double maxVal = 0.0;

      bool isZeroBased = rawStats.keys.contains(0);

      rawStats.forEach((k, v) {
        int uiKey = isZeroBased ? k + 1 : k;
        if (uiKey < 1 || uiKey > 12) return;

        final parsed = _parseValue(v);
        values[uiKey] = parsed;
        displayStrings[uiKey] = v;

        if (parsed > maxVal) maxVal = parsed;
      });

      if (mounted) {
        setState(() {
          _monthlyDisplayStrings = displayStrings;
          _monthlyGraphValues = values;
          _maxGraphValue = maxVal <= 0 ? 1.0 : maxVal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Maps remain empty as set at start of method
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = widget.availableYears.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    // Safety fallback
    if (years.isEmpty) years.add(DateTime.now().year);

    return Container(
      height:
          MediaQuery.of(context).size.height *
          0.45, // Slightly taller for safety
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Machine',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    widget.onApply(_tempYear, _tempMonth);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Graph Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _monthlyGraphValues.isEmpty
                // Show a friendly message if data is empty (but loaded)
                ? Center(
                    child: Text(
                      "No data for $_tempYear",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView.separated(
                        controller: _monthScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: 12,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: _kMonthGap),
                        itemBuilder: (context, index) {
                          // UI uses 1-based index (1=Jan)
                          final monthIndex = index + 1;

                          final rawValue =
                              _monthlyGraphValues[monthIndex] ?? 0.0;

                          // Calculate percentage safely
                          final percentage = (rawValue / _maxGraphValue).clamp(
                            0.05, // Minimum height for visibility
                            1.0,
                          );

                          return SizedBox(
                            width: _kMonthItemWidth,
                            child: _GraphBarItem(
                              monthIndex: monthIndex,
                              label: _getMonthAbbr(monthIndex),
                              displayValue: _monthlyDisplayStrings[monthIndex],
                              percentage: percentage,
                              isSelected: _tempMonth == monthIndex,
                              maxHeight: constraints.maxHeight,
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

          const SizedBox(height: 24),

          // Year Selector
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        year.toString(),
                        style: TextStyle(
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
    // Safety check for index
    if (index < 1 || index > 12) return '';
    return months[index - 1];
  }
}

/// Helper Widget: A single month bar in the graph
class _GraphBarItem extends StatelessWidget {
  final int monthIndex;
  final String label;
  final String? displayValue;
  final double percentage;
  final bool isSelected;
  final double maxHeight;
  final VoidCallback onTap;

  const _GraphBarItem({
    required this.monthIndex,
    required this.label,
    required this.displayValue,
    required this.percentage,
    required this.isSelected,
    required this.maxHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Height calculation
    final barHeight = maxHeight * 0.60 * percentage;
    const double barWidth = 32.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Pushes content down
          const Spacer(),

          // --- FIX START ---
          if (isSelected && displayValue != null)
            // UnconstrainedBox allows the badge to be wider than the column (48px)
            // It will center itself and overlap neighbors if the text is long.
            UnconstrainedBox(
              constrainedAxis: Axis.vertical,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  displayValue!,
                  style: TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  softWrap: false, // Ensure it stays on one line
                ),
              ),
            ),
          // --- FIX END ---

          // The Bar Stack
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Container(
              //   width: barWidth,
              //   height: maxHeight * 0.60,
              //   decoration: BoxDecoration(
              //     color: theme.colorScheme.surfaceContainerHighest.withValues(
              //       alpha: 0.3,
              //     ),
              //     borderRadius: BorderRadius.circular(6),
              //   ),
              // ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
