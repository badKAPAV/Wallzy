import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/screens/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/screens/transaction_list_item.dart';

// Enum to manage the state of the custom date filters
enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisFiscalYear,
  lastFiscalYear,
  custom
}

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late TransactionFilter _filter;
  FilterResult? _result;

  // State variables for the advanced date filter
  DateFilterType? _selectedFilterType;
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _filter = const TransactionFilter();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions =
        Provider.of<TransactionProvider>(context, listen: false).transactions;

    final years =
        allTransactions.map((tx) => tx.timestamp.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));

    setState(() {
      _availableYears = years;
      final now = DateTime.now();
      _selectedYear = now.year;
      if (_availableYears.isNotEmpty && !_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    });

    _updateDateFilter(year: _selectedYear);
  }

  void _runFilter() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    setState(() {
      _result = provider.getFilteredResults(_filter);
    });
  }

  void _updateFilter(TransactionFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _runFilter();
  }

  // Central logic hub for updating date filters
  void _updateDateFilter({
    DateFilterType? type,
    int? year,
    int? month,
    DateTimeRange? customRange,
  }) {
    final now = DateTime.now();
    DateTimeRange range = _getYearRange(now.year);

    // This logic now primarily updates the state variables.
    // The range calculation will be based on the final state.
    setState(() {
      _selectedFilterType = type;
      _selectedYear = year;
      _selectedMonth = month;
    });

    if (customRange != null) {
      range = customRange;
    } else if (_selectedFilterType != null) {
      range = _getRangeForType(_selectedFilterType!);
    } else if (_selectedYear != null) {
      if (_selectedMonth != null) {
        range = _getMonthRange(_selectedYear!, _selectedMonth!);
      } else {
        range = _getYearRange(_selectedYear!);
      }
    }

    _updateFilter(_filter.copyWith(
      startDate: () => range.start,
      endDate: () =>
          DateTime(range.end.year, range.end.month, range.end.day + 1),
    ));
  }

  // Helper to generate the dynamic label for the main date filter chip
  String _getDateFilterLabel() {
    if (_selectedFilterType != null) {
      switch (_selectedFilterType!) {
        case DateFilterType.today:
          return 'Today';
        case DateFilterType.yesterday:
          return 'Yesterday';
        case DateFilterType.thisWeek:
          return 'This Week';
        case DateFilterType.lastWeek:
          return 'Last Week';
        case DateFilterType.thisMonth:
          return 'This Month';
        case DateFilterType.lastMonth:
          return 'Last Month';
        case DateFilterType.thisQuarter:
          return 'This Quarter';
        case DateFilterType.lastQuarter:
          return 'Last Quarter';
        case DateFilterType.thisFiscalYear:
          return 'This Fiscal Year';
        case DateFilterType.lastFiscalYear:
          return 'Last Fiscal Year';
        case DateFilterType.custom:
          if (_filter.startDate != null && _filter.endDate != null) {
            final start = DateFormat.MMMd().format(_filter.startDate!);
            final end = DateFormat.yMMMd()
                .format(_filter.endDate!.subtract(const Duration(days: 1)));
            if (start == end) return start;
            return '$start - $end';
          }
          return 'Custom';
      }
    }

    if (_selectedYear != null) {
      if (_selectedMonth != null) {
        return '${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}, $_selectedYear';
      }
      return _selectedYear.toString();
    }
    return 'Select Date';
  }

  // Helper to format the "Showing results for..." text
  String _getFormattedDateRangeLabel() {
    if (_filter.startDate == null || _filter.endDate == null) {
      return 'Showing results for All Time';
    }

    final start = _filter.startDate!;
    final end = _filter.endDate!.subtract(const Duration(days: 1));

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return 'Showing results for ${DateFormat('EEEE, d MMMM, yyyy').format(start)}';
    }

    final startFormat = DateFormat('d MMM, yyyy');
    final endFormat = DateFormat('d MMM, yyyy');
    return 'Showing results for ${startFormat.format(start)} - ${endFormat.format(end)}';
  }

  // Shows the Date Filter Bottom Modal Sheet
  void _showDateFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _DateFilterModalContent(
          initialFilterType: _selectedFilterType,
          initialYear: _selectedYear,
          initialMonth: _selectedMonth,
          initialCustomRange:
              (_filter.startDate != null && _filter.endDate != null)
                  ? DateTimeRange(
                      start: _filter.startDate!,
                      end: _filter.endDate!.subtract(const Duration(days: 1)))
                  : null,
          availableYears: _availableYears,
          onApply: (type, year, month, customRange) {
            if (type == DateFilterType.custom) {
              _updateDateFilter(
                type: type,
                year: null,
                month: null,
                customRange: customRange,
              );
            } else {
              _updateDateFilter(
                type: type,
                year: year,
                month: month,
              );
            }
          },
        );
      },
    );
  }

  // Shows the general Filters Bottom Modal Sheet
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _FilterModalContent(
          initialFilter: _filter,
          onApply: (newFilter) {
            _updateFilter(newFilter);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final result = _result!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          if (_filter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Clear All Filters',
              onPressed: () {
                _updateFilter(TransactionFilter.empty);
                setState(() {
                  _selectedFilterType = null;
                  _selectedMonth = null;
                  _selectedYear = DateTime.now().year;
                });
                _updateDateFilter(year: DateTime.now().year);
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(result: result),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_getDateFilterLabel()),
                  onPressed: _showDateFilterModal,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filters'),
                  onPressed: _showFilterModal,
                ),
              ],
            ),
          ),
          // "Showing results for..." text label
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
            child: Text(
              _getFormattedDateRangeLabel(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: result.transactions.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: result.transactions.length,
                    itemBuilder: (context, index) {
                      final tx = result.transactions[index];
                      return TransactionListItem(
                        transaction: tx,
                        onTap: () => _showTransactionDetails(context, tx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(
      BuildContext context, TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }
}

// =========================================================================
// SECTION: Stateful Widgets for Modal Content
// =========================================================================

class _DateFilterModalContent extends StatefulWidget {
  final DateFilterType? initialFilterType;
  final int? initialYear;
  final int? initialMonth;
  final DateTimeRange? initialCustomRange;
  final List<int> availableYears;
  final Function(DateFilterType?, int?, int?, DateTimeRange?) onApply;

  const _DateFilterModalContent({
    required this.initialFilterType,
    required this.initialYear,
    required this.initialMonth,
    required this.initialCustomRange,
    required this.availableYears,
    required this.onApply,
  });

  @override
  State<_DateFilterModalContent> createState() =>
      _DateFilterModalContentState();
}

class _DateFilterModalContentState extends State<_DateFilterModalContent> {
  late DateFilterType? tempFilterType;
  late int? tempYear;
  late int? tempMonth;
  late DateTimeRange? tempCustomRange;

  @override
  void initState() {
    super.initState();
    tempFilterType = widget.initialFilterType;
    tempYear = widget.initialYear;
    tempMonth = widget.initialMonth;
    tempCustomRange = widget.initialCustomRange;
  }

  void handleSelection({DateFilterType? type, int? year, int? month}) {
    setState(() {
      final now = DateTime.now();
      if (type != null) {
        tempFilterType = tempFilterType == type ? null : type;
        tempYear = null;
        tempMonth = null;
        if (tempFilterType == null) tempYear = now.year;
      } else if (month != null) {
        tempFilterType = null;
        tempMonth = tempMonth == month ? null : month;
        tempYear ??= now.year;
      } else if (year != null) {
        tempFilterType = null;
        tempYear = tempYear == year ? null : year;
        tempMonth = null;
        if (tempYear == null) tempFilterType = DateFilterType.today;
      }
    });
  }

  Future<void> pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      initialDateRange: tempCustomRange,
    );
    if (picked != null) {
      setState(() {
        tempFilterType = DateFilterType.custom;
        tempYear = null;
        tempMonth = null;
        tempCustomRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Date Range',
                  style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                iconSize: 30,
                tooltip: 'Apply',
                onPressed: () {
                  widget.onApply(
                      tempFilterType, tempYear, tempMonth, tempCustomRange);
                  Navigator.pop(context);
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          _DateFilterSection(
            selectedFilterType: tempFilterType,
            selectedMonth: tempMonth,
            selectedYear: tempYear,
            availableYears: widget.availableYears,
            onTypeSelected: (type) => handleSelection(type: type),
            onMonthSelected: (month) => handleSelection(month: month),
            onYearSelected: (year) => handleSelection(year: year),
            onCustomDateTap: pickCustomDate,
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ],
      ),
    );
  }
}

class _FilterModalContent extends StatefulWidget {
  final TransactionFilter initialFilter;
  final Function(TransactionFilter) onApply;

  const _FilterModalContent({
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<_FilterModalContent> createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<_FilterModalContent> {
  late String? tempType;
  late List<String> tempCategories;
  late List<Tag> tempTags;
  late List<Person> tempPeople;
  // ** NEW ** State for payment methods
  late List<String> tempPaymentMethods;

  // ** NEW ** Static list of payment methods
  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'UPI',
    'Net Banking',
  ];

  @override
  void initState() {
    super.initState();
    tempType = widget.initialFilter.type;
    tempCategories = List.from(widget.initialFilter.categories ?? []);
    tempTags = List.from(widget.initialFilter.tags ?? []);
    tempPeople = List.from(widget.initialFilter.people ?? []);
    tempPaymentMethods = List.from(widget.initialFilter.paymentMethods ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final allTags = metaProvider.tags;
    final allPeople = metaProvider.people;

    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => setState(() {
                      tempType = null;
                      tempCategories.clear();
                      tempTags.clear();
                      tempPeople.clear();
                      tempPaymentMethods.clear();
                    }),
                    child: const Text('Reset'),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String?>(
                multiSelectionEnabled: false,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                ],
                selected: {tempType},
                onSelectionChanged: (newSelection) =>
                    setState(() => tempType = newSelection.first),
              ),
              const SizedBox(height: 24),
              Text('Categories',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ({
                  ...TransactionCategories.income,
                  ...TransactionCategories.expense
                }.toList()..sort())
                    .map((category) {
                  final isSelected = tempCategories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          tempCategories.add(category);
                        } else {
                          tempCategories.remove(category);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              // ** NEW ** Payment Method Filter Section
              const SizedBox(height: 24),
              Text('Payment Methods',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentMethods.map((method) {
                  final isSelected = tempPaymentMethods.contains(method);
                  return FilterChip(
                    label: Text(method),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          tempPaymentMethods.add(method);
                        } else {
                          tempPaymentMethods.remove(method);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (allTags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Tags', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    final isSelected = tempTags.any((t) => t.id == tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            tempTags.add(tag);
                          } else {
                            tempTags.removeWhere((t) => t.id == tag.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (allPeople.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('People', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allPeople.map((person) {
                    final isSelected = tempPeople.any((p) => p.id == person.id);
                    return FilterChip(
                      label: Text(person.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            tempPeople.add(person);
                          } else {
                            tempPeople.removeWhere((p) => p.id == person.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final newFilter = widget.initialFilter.copyWith(
                      type: () => tempType,
                      categories: () =>
                          tempCategories.isEmpty ? null : tempCategories,
                      tags: () => tempTags.isEmpty ? null : tempTags,
                      people: () => tempPeople.isEmpty ? null : tempPeople,
                      // ** NEW ** Apply payment methods to the filter
                      paymentMethods: () =>
                          tempPaymentMethods.isEmpty ? null : tempPaymentMethods,
                    );
                    widget.onApply(newFilter);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// SECTION: UI Widgets (Stateless)
// =========================================================================

class _DateFilterSection extends StatelessWidget {
  final DateFilterType? selectedFilterType;
  final int? selectedYear;
  final int? selectedMonth;
  final List<int> availableYears;
  final Function(DateFilterType) onTypeSelected;
  final Function(int) onYearSelected;
  final Function(int) onMonthSelected;
  final VoidCallback onCustomDateTap;

  const _DateFilterSection({
    required this.selectedFilterType,
    required this.selectedYear,
    required this.selectedMonth,
    required this.availableYears,
    required this.onTypeSelected,
    required this.onYearSelected,
    required this.onMonthSelected,
    required this.onCustomDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeframes = {
      'Today': DateFilterType.today, 'Yesterday': DateFilterType.yesterday,
      'This Week': DateFilterType.thisWeek, 'Last Week': DateFilterType.lastWeek,
      'This Month': DateFilterType.thisMonth, 'Last Month': DateFilterType.lastMonth,
      'This Quarter': DateFilterType.thisQuarter, 'Last Quarter': DateFilterType.lastQuarter,
      'This Fiscal Year': DateFilterType.thisFiscalYear, 'Last Fiscal Year': DateFilterType.lastFiscalYear,
    };

    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Custom Timeframes
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...timeframes.entries.map((entry) => _CustomFilterChip(
                    label: entry.key,
                    isSelected: selectedFilterType == entry.value,
                    onTap: () => onTypeSelected(entry.value),
                  )),
              _CustomFilterChip(
                label: 'Custom',
                isSelected: selectedFilterType == DateFilterType.custom,
                onTap: onCustomDateTap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Row 2 & 3: Months and Years
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...months.entries.map((entry) => _CustomFilterChip(
                    label: entry.key,
                    isSelected: selectedMonth == entry.value,
                    onTap: () => onMonthSelected(entry.value),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableYears
                .map((year) => _CustomFilterChip(
                      label: year.toString(),
                      isSelected: selectedYear == year,
                      onTap: () => onYearSelected(year),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: isSelected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 4),
                  const Icon(Icons.cancel, size: 16),
                ],
              )
            : Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: isSelected
            ? TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)
            : null,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FilterResult result;
  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryColumn(
                title: 'Income',
                amount: currencyFormat.format(result.totalIncome),
                color: Colors.green),
            _SummaryColumn(
                title: 'Expense',
                amount: currencyFormat.format(result.totalExpense),
                color: Colors.red),
            _SummaryColumn(
                title: 'Balance',
                amount: currencyFormat.format(result.balance),
                color: result.balance >= 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.red),
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  const _SummaryColumn(
      {required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(amount,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No Transactions Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Try adjusting your filters.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// =========================================================================
// SECTION: Date Range Calculation Helpers
// =========================================================================

extension _DateHelpers on _AllTransactionsScreenState {
  DateTimeRange _getRangeForType(DateFilterType type) {
    final now = DateTime.now();
    switch (type) {
      case DateFilterType.today:
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
      case DateFilterType.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTimeRange(
            start: DateTime(yesterday.year, yesterday.month, yesterday.day),
            end: DateTime(yesterday.year, yesterday.month, yesterday.day));
      case DateFilterType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
            start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            end: now);
      case DateFilterType.lastWeek:
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        final startOfLastWeek = endOfLastWeek.subtract(const Duration(days: 6));
        return DateTimeRange(
            start:
                DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day),
            end: DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day));
      case DateFilterType.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case DateFilterType.lastMonth:
        final firstDayOfThisMonth = DateTime(now.year, now.month, 1);
        final endOfLastMonth =
            firstDayOfThisMonth.subtract(const Duration(days: 1));
        final startOfLastMonth =
            DateTime(endOfLastMonth.year, endOfLastMonth.month, 1);
        return DateTimeRange(start: startOfLastMonth, end: endOfLastMonth);
      case DateFilterType.thisQuarter:
        final quarter = (now.month - 1) ~/ 3 + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        final startOfQuarter = DateTime(now.year, startMonth, 1);
        return DateTimeRange(start: startOfQuarter, end: now);
      case DateFilterType.lastQuarter:
        final currentQuarter = (now.month - 1) ~/ 3 + 1;
        final startMonthOfCurrentQuarter = (currentQuarter - 1) * 3 + 1;
        final endOfLastQuarter = DateTime(now.year, startMonthOfCurrentQuarter, 1)
            .subtract(const Duration(days: 1));
        final startOfLastQuarter =
            DateTime(endOfLastQuarter.year, endOfLastQuarter.month - 2, 1);
        return DateTimeRange(start: startOfLastQuarter, end: endOfLastQuarter);
      case DateFilterType.thisFiscalYear:
        final startYear = (now.month < 4) ? now.year - 1 : now.year;
        return DateTimeRange(start: DateTime(startYear, 4, 1), end: now);
      case DateFilterType.lastFiscalYear:
        final startYearOfCurrent = (now.month < 4) ? now.year - 1 : now.year;
        final startOfLastFiscalYear = DateTime(startYearOfCurrent - 1, 4, 1);
        final endOfLastFiscalYear = DateTime(startYearOfCurrent, 3, 31);
        return DateTimeRange(
            start: startOfLastFiscalYear, end: endOfLastFiscalYear);
      case DateFilterType.custom:
        return DateTimeRange(
            start: _filter.startDate ?? now,
            end: _filter.endDate?.subtract(const Duration(days: 1)) ?? now);
    }
  }

  DateTimeRange _getYearRange(int year) {
    return DateTimeRange(
        start: DateTime(year, 1, 1), end: DateTime(year, 12, 31));
  }

  DateTimeRange _getMonthRange(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = (month == 12)
        ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
        : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    return DateTimeRange(start: firstDay, end: lastDay);
  }
}