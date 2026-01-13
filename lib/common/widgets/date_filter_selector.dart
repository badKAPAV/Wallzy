import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DateNavigationControl extends StatefulWidget {
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

  @override
  State<DateNavigationControl> createState() => _DateNavigationControlState();
}

class _DateNavigationControlState extends State<DateNavigationControl> {
  int _slideDirection = 1; // 1 for Next (Up), -1 for Prev (Down)
  bool _isLeftAligned = true;
  bool _isLoaded = false;

  bool get isYearMode => widget.selectedMonth == null;

  @override
  void initState() {
    super.initState();
    _loadAlignmentPref();
  }

  Future<void> _loadAlignmentPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLeftAligned = prefs.getBool('date_nav_alignment_left') ?? true;
        _isLoaded = true;
      });
    }
  }

  Future<void> _toggleAlignment() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLeftAligned = !_isLeftAligned;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('date_nav_alignment_left', _isLeftAligned);
  }

  @override
  void didUpdateWidget(DateNavigationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedYear > oldWidget.selectedYear) {
      _slideDirection = 1;
    } else if (widget.selectedYear < oldWidget.selectedYear) {
      _slideDirection = -1;
    } else {
      final newM = widget.selectedMonth ?? 0;
      final oldM = oldWidget.selectedMonth ?? 0;
      if (newM > oldM) {
        _slideDirection = 1;
      } else if (newM < oldM) {
        _slideDirection = -1;
      }
    }
  }

  void _handlePrevious() {
    HapticFeedback.lightImpact();
    if (isYearMode) {
      widget.onDateChanged(widget.selectedYear - 1, null);
    } else {
      int newMonth = widget.selectedMonth! - 1;
      int newYear = widget.selectedYear;
      if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      widget.onDateChanged(newYear, newMonth);
    }
  }

  void _handleNext() {
    HapticFeedback.lightImpact();
    if (isYearMode) {
      widget.onDateChanged(widget.selectedYear + 1, null);
    } else {
      int newMonth = widget.selectedMonth! + 1;
      int newYear = widget.selectedYear;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      }
      widget.onDateChanged(newYear, newMonth);
    }
  }

  String _getMonthName(int index) {
    const months = [
      "",
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC",
    ];
    if (index < 1 || index > 12) return "";
    return months[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final textKey = ValueKey("${widget.selectedYear}-${widget.selectedMonth}");

    // Prevent layout jumps before prefs are loaded
    if (!_isLoaded) return const SizedBox(height: 64);

    return SizedBox(
      height: 64,
      width: double.infinity,
      child: Stack(
        // Use Stack to overlay the Main Pill and the Toggle Button
        children: [
          // ---------------------------------------------------------
          // 1. THE MAIN PILL
          // ---------------------------------------------------------
          // Using AnimatedAlign ensures a smooth slide across the screen
          AnimatedAlign(
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastEaseInToSlowEaseOut,
            alignment: _isLeftAligned
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                constraints: const BoxConstraints(minWidth: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Layout order flips based on alignment
                    if (_isLeftAligned) ...[
                      // Left-aligned: Buttons -> Text
                      _SeparateButtonsGroup(
                        onPrev: _handlePrevious,
                        onNext: _handleNext,
                        theme: theme,
                      ),
                      const SizedBox(width: 16),
                      _DateText(
                        textKey: textKey,
                        slideDirection: _slideDirection,
                        isYearMode: isYearMode,
                        monthName: _getMonthName(widget.selectedMonth ?? 0),
                        year: widget.selectedYear,
                        onTap: widget.onTapPill,
                        theme: theme,
                        isLeftAligned: _isLeftAligned,
                      ),
                    ] else ...[
                      // Right-aligned: Text -> Buttons
                      _DateText(
                        textKey: textKey,
                        slideDirection: _slideDirection,
                        isYearMode: isYearMode,
                        monthName: _getMonthName(widget.selectedMonth ?? 0),
                        year: widget.selectedYear,
                        onTap: widget.onTapPill,
                        theme: theme,
                        isLeftAligned: _isLeftAligned,
                      ),
                      const SizedBox(width: 16),
                      _SeparateButtonsGroup(
                        onPrev: _handlePrevious,
                        onNext: _handleNext,
                        theme: theme,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 2. THE ALIGNMENT TOGGLE BUTTON
          // ---------------------------------------------------------
          // Also uses AnimatedAlign to slide to the opposite side
          AnimatedAlign(
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastEaseInToSlowEaseOut,
            alignment: _isLeftAligned
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleAlignment,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.surface.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      _isLeftAligned
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: theme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _SeparateButtonsGroup extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ColorScheme theme;

  const _SeparateButtonsGroup({
    required this.onPrev,
    required this.onNext,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.chevron_left_rounded,
          onTap: onPrev,
          color: theme.primaryContainer,
          iconColor: theme.onPrimaryContainer,
        ),
        const SizedBox(width: 8), // Distinct separation
        _CircleButton(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
          color: theme.primaryContainer,
          iconColor: theme.onPrimaryContainer,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 26, color: iconColor),
      ),
    );
  }
}

class _DateText extends StatelessWidget {
  final Key textKey;
  final int slideDirection;
  final bool isYearMode;
  final String monthName;
  final int year;
  final VoidCallback onTap;
  final ColorScheme theme;
  final bool isLeftAligned;

  const _DateText({
    required this.textKey,
    required this.slideDirection,
    required this.isYearMode,
    required this.monthName,
    required this.year,
    required this.onTap,
    required this.theme,
    required this.isLeftAligned,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLeftAligned) ...[
              Icon(
                Icons.arrow_back_ios_rounded,
                color: theme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
            ],
            ClipRect(
              child: SizedBox(
                height: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInBack,
                  transitionBuilder: (child, animation) {
                    final isNewChild = child.key == textKey;
                    final double yStart = isNewChild
                        ? (slideDirection > 0 ? 1.0 : -1.0)
                        : 0.0;
                    final double yEnd = isNewChild
                        ? 0.0
                        : (slideDirection > 0 ? -1.0 : 1.0);

                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, yStart),
                        end: Offset(0, yEnd),
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: textKey,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: isLeftAligned
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      if (!isYearMode)
                        Text(
                          monthName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.onSurface,
                                fontSize: 18,
                                height: 1.0,
                                letterSpacing: 0.5,
                              ),
                        ),
                      if (!isYearMode) const SizedBox(height: 2),
                      Text(
                        "$year",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.onSurface.withOpacity(0.9),
                          height: 1.0,
                          fontWeight: isYearMode
                              ? FontWeight.w900
                              : FontWeight.normal,
                          fontSize: isYearMode ? 18 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isLeftAligned) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.primary,
                size: 16,
              ),
            ],
          ],
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
