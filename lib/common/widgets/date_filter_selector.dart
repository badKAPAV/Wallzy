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

/// A flexible modal bottom sheet for selecting Year and Month.
/// Supports a "Time Machine" vibe with Wrap for years and Grid for months.
class DateFilterModal extends StatefulWidget {
  final List<int> availableYears;
  final int initialYear;
  final int? initialMonth;
  final Function(int year, int? month) onApply;

  /// Optional callback to fetch stats string (e.g. "₹20k") for each month of a year.
  /// Returns a map where key is month index (1-12) and value is the label.
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
  Map<int, String> _monthlyStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tempYear = widget.initialYear;
    _tempMonth = widget.initialMonth;

    if (widget.onStatsRequired != null) {
      _fetchStats(_tempYear); // Fetch stats for initial year
    }
  }

  Future<void> _fetchStats(int year) async {
    if (widget.onStatsRequired == null) return;

    setState(() => _isLoading = true);
    try {
      final stats = await widget.onStatsRequired!(year);
      if (mounted) {
        setState(() {
          _monthlyStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final theme = Theme.of(context);

    // Filter available years to ensure they are unique and sorted
    final years = widget.availableYears.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    // Fallback if no years provided
    if (years.isEmpty && widget.availableYears.isEmpty) {
      years.add(DateTime.now().year);
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
                onPressed: () {
                  widget.onApply(_tempYear, _tempMonth);
                  Navigator.pop(context);
                },
                child: Text(
                  'Apply',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'YEAR',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Years Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: years
                .map(
                  (year) => ChipFilterItem(
                    label: year.toString(),
                    isSelected: _tempYear == year,
                    onTap: () {
                      if (_tempYear != year) {
                        setState(() => _tempYear = year);
                        _fetchStats(year);
                      }
                    },
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 24),
          Text(
            'MONTH',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Months Grid
          _isLoading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 2,
                  children: months.entries.map((entry) {
                    final stat = _monthlyStats[entry.value];
                    return ChipFilterItem(
                      label: entry.key,
                      isSelected: _tempMonth == entry.value,
                      isCompact: true,
                      subLabel: stat,
                      onTap: () => setState(
                        () => _tempMonth = _tempMonth == entry.value
                            ? null
                            : entry.value,
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// A generic chip item used in the filter modal
class ChipFilterItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;
  final String? subLabel;

  const ChipFilterItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
    this.subLabel, // Optional small text below label (e.g. amount)
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 0 : 10,
          vertical: 8,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Helper method to show the modal
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
    isScrollControlled: true, // Important for wrapping content
    builder: (ctx) => SingleChildScrollView(
      child: DateFilterModal(
        availableYears: availableYears,
        initialYear: initialYear,
        initialMonth: initialMonth,
        onApply: onApply,
        onStatsRequired: onStatsRequired,
      ),
    ),
  );
}
