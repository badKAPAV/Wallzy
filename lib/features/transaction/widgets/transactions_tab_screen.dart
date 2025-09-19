import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class TransactionsTabScreen extends StatefulWidget {
  const TransactionsTabScreen();

  @override
  State<TransactionsTabScreen> createState() => TransactionsTabScreenState();
}

class TransactionsTabScreenState extends State<TransactionsTabScreen> {
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  FilterResult? _result;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions =
        Provider.of<TransactionProvider>(context, listen: false).transactions;
    if (allTransactions.isNotEmpty) {
      final years =
          allTransactions.map((tx) => tx.timestamp.year).toSet().toList();
      years.sort((a, b) => b.compareTo(a));
      _availableYears = years;
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    } else {
      _availableYears = [_selectedYear];
    }
    _runFilter();
  }

  void _runFilter() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final range = _getFilterRange();
    final filter = TransactionFilter(
      startDate: range.start,
      // Add 1 day to end date to make it inclusive
      endDate: range.end.add(const Duration(days: 1)),
    );
    setState(() {
      _result = provider.getFilteredResults(filter);
    });
  }

  DateTimeRange _getFilterRange() {
    if (_selectedMonth != null) {
      final firstDay = DateTime(_selectedYear, _selectedMonth!, 1);
      final lastDay = (_selectedMonth == 12)
          ? DateTime(_selectedYear + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(_selectedYear, _selectedMonth! + 1, 1)
              .subtract(const Duration(days: 1));
      return DateTimeRange(start: firstDay, end: lastDay);
    } else {
      return DateTimeRange(
        start: DateTime(_selectedYear, 1, 1),
        end: DateTime(_selectedYear, 12, 31),
      );
    }
  }

  String _getFilterLabel() {
    if (_selectedMonth != null) {
      return '${DateFormat.MMMM().format(DateTime(0, _selectedMonth!))}, $_selectedYear';
    }
    return _selectedYear.toString();
  }

  void _showDateFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _DateFilterModal(
        availableYears: _availableYears,
        initialYear: _selectedYear,
        initialMonth: _selectedMonth,
        onApply: (year, month) {
          setState(() {
            _selectedYear = year;
            _selectedMonth = month;
          });
          _runFilter();
        },
      ),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
      List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      String key;
      if (txDate.isAtSameMomentAs(today)) {
        key = 'Today';
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('d MMMM, yyyy').format(txDate);
      }
      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final groupedTransactions =
        _groupTransactionsByDate(_result!.transactions);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _DateFilterHeader(
            label: _getFilterLabel(),
            onTap: _showDateFilterModal,
          ),
        ),
        SliverToBoxAdapter(child: _SummaryAndChart(result: _result!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'All Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (_result!.transactions.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dateKey = groupedTransactions.keys.elementAt(index);
                final transactionsForDate = groupedTransactions[dateKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        dateKey,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    ...transactionsForDate.map(
                      (tx) => TransactionListItem(
                        transaction: tx,
                        onTap: () => _showTransactionDetails(context, tx),
                      ),
                    ),
                  ],
                );
              },
              childCount: groupedTransactions.length,
            ),
          ),
      ],
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }
}

class _DateFilterHeader extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateFilterHeader({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Transactions in', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 4,),
              Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).colorScheme.primary)
            ],
          ),
        ),
      ),
    );
  }
}

class _DateFilterModal extends StatefulWidget {
  final List<int> availableYears;
  final int initialYear;
  final int? initialMonth;
  final Function(int year, int? month) onApply;

  const _DateFilterModal({
    required this.availableYears,
    required this.initialYear,
    required this.initialMonth,
    required this.onApply,
  });

  @override
  State<_DateFilterModal> createState() => _DateFilterModalState();
}

class _DateFilterModalState extends State<_DateFilterModal> {
  late int _tempYear;
  late int? _tempMonth;
  Map<int, double> _monthlyExpenses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tempYear = widget.initialYear;
    _tempMonth = widget.initialMonth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMonthlyExpenses(_tempYear);
    });
  }

  Future<void> _calculateMonthlyExpenses(int year) async {
    setState(() {
      _isLoading = true;
    });
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    Map<int, double> expenses = {};
    for (int month = 1; month <= 12; month++) {
      final range = DateTimeRange(
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
      );
      final filter = TransactionFilter(
        startDate: range.start,
        endDate: range.end.add(const Duration(days: 1)),
        type: 'expense',
      );
      final result = provider.getFilteredResults(filter);
      expenses[month] = result.totalExpense;
    }
    if (mounted) {
      setState(() {
        _monthlyExpenses = expenses;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final currencyFormat =
        NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);

        final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: width * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Period',
                        style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                    Text('Select a month or deselect it to view transactions for the whole year.', softWrap: true, style: Theme.of(context).textTheme.bodySmall)
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onApply(_tempYear, _tempMonth);
                  Navigator.pop(context);
                },
                child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(30)), child: Padding(
                
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Months', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: months.entries.map((entry) {
                      final expense = _monthlyExpenses[entry.value] ?? 0.0;
                      return _FilterItem(
                        label: entry.key,
                        subLabel:
                            expense > 0 ? currencyFormat.format(expense) : null,
                        isSelected: _tempMonth == entry.value,
                        onTap: () {
                          setState(() {
                            _tempMonth =
                                _tempMonth == entry.value ? null : entry.value;
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          Text('Years', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.availableYears.map((year) {
                return _FilterItem(
                  label: year.toString(),
                  isSelected: _tempYear == year,
                  onTap: () {
                    if (_tempYear != year) {
                      setState(() {
                        _tempYear = year;
                      });
                      _calculateMonthlyExpenses(year);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterItem({
    required this.label,
    this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 80,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryAndChart extends StatelessWidget {
  final FilterResult result;
  const _SummaryAndChart({required this.result});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final total = result.totalIncome + result.totalExpense;
    final incomePercent = total > 0 ? (result.totalIncome.toDouble() / total) * 100 : 0.0;
    final expensePercent = total > 0 ? (result.totalExpense.toDouble() / total) * 100 : 0.0;
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: (total > 0)
                          ? [
                              PieChartSectionData(
                                value: incomePercent,
                                color: appColors.income,
                                radius: 10,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: expensePercent,
                                color: appColors.expense,
                                radius: 10,
                                showTitle: false,
                              ),
                            ]
                          : [
                              PieChartSectionData(
                                value: 100,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                                radius: 10,
                                showTitle: false,
                              ),
                            ],
                      sectionsSpace: 6,
                      centerSpaceRadius: 90,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.1), shape: BoxShape.circle), child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.compare_arrows_rounded, color: colorScheme.onSurface,),
                      )),
                      const SizedBox(height: 10),
                      Text(
                        currencyFormat.format(result.balance),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text('Balance', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant))
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryColumn(
                  title: 'Income',
                  amount: currencyFormat.format(result.totalIncome),
                  color: appColors.income,
                ),
                _SummaryColumn(
                  title: 'Expense',
                  amount: currencyFormat.format(result.totalExpense),
                  color: appColors.expense,
                ),
              ],
            ),
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

  const _SummaryColumn({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = title.toLowerCase() == 'income' ? Icons.call_received_rounded : Icons.arrow_outward_rounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(icon, color: color, size: 20,),)
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your date filter.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}