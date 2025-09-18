import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transaction_list_item.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalAmount;

  _MonthlySummary({required this.month, required this.totalAmount});
}

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryName;
  final String categoryType;
  final DateTime initialSelectedDate;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryName,
    required this.categoryType,
    required this.initialSelectedDate,
  });

  @override
  State<CategoryTransactionsScreen> createState() =>
      _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState
    extends State<CategoryTransactionsScreen> {
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxSpent = 0;
  double _meanSpent = 0;
  String _transactionType = 'expense';
  List<TransactionModel> _allCategoryTransactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndProcessTransactions();
    });
  }

  void _loadAndProcessTransactions() {
    final allTransactions =
        Provider.of<TransactionProvider>(context, listen: false).transactions;
    _allCategoryTransactions = allTransactions
        .where((tx) =>
            tx.category == widget.categoryName && tx.type == widget.categoryType)
        .toList();

    if (_allCategoryTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
        _transactionType = widget.categoryType;
      });
    }
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _allCategoryTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
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

  void _processTransactions() {
    _transactionType = widget.categoryType;

    final groupedByMonth = groupBy(
      _allCategoryTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    final summaries = groupedByMonth.entries.map((entry) {
      final total = entry.value.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return _MonthlySummary(month: entry.key, totalAmount: total);
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxSpent =
          summaries.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);
      final totalSum =
          summaries.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
      _meanSpent = totalSum / summaries.length;
    }

    setState(() {
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        final initialMonthDate = DateTime(
            widget.initialSelectedDate.year, widget.initialSelectedDate.month);
        final hasDataInInitialMonth =
            _monthlySummaries.any((s) => s.month == initialMonthDate);

        _selectMonth(hasDataInInitialMonth
            ? initialMonthDate
            : _monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.categoryName),
            const SizedBox(height: 4,),
            Text(
            widget.categoryType == 'expense' ? 'Expense' : 'Income',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement search functionality
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildGraphSection(currencyFormat),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_displayTransactions.length} transactions',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: Text(
                      'No transactions in this category for the selected period.')),
            )
          else
            _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    const double barWidth = 50.0;
    const double barSpacing = 24.0;
    final double chartWidth = _monthlySummaries.length * (barWidth + barSpacing);

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, right: 10),
            child: SizedBox(
              height: 190,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Max\n${currencyFormat.format(_maxSpent)}', style: Theme.of(context).textTheme.bodySmall),
                  Text('Mean\n${currencyFormat.format(_meanSpent)}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 1),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: chartWidth,
                height: 250,
                child: BarChart(
                  BarChartData(
                    groupsSpace: 40,
                    maxY: _maxSpent == 0 ? 1 : _maxSpent * 1.1,
                    barTouchData: _buildBarTouchData(),
                    titlesData: _buildTitlesData(currencyFormat),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: _buildBarGroups(),
                    alignment: BarChartAlignment.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        // tooltipBgColor: Colors.transparent,
        tooltipPadding: EdgeInsets.zero,
        tooltipMargin: 4,
        getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
      ),
      touchCallback: (FlTouchEvent event, barTouchResponse) {
        if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
          final index = barTouchResponse!.spot!.touchedBarGroupIndex;
          if (index >= 0 && index < _monthlySummaries.length) {
            _selectMonth(_monthlySummaries[index].month);
          }
        }
      },
    );
  }

  FlTitlesData _buildTitlesData(NumberFormat currencyFormat) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            final index = value.toInt();
            if (index < 0 || index >= _monthlySummaries.length) return const SizedBox();

            final summary = _monthlySummaries[index];
            final isSelected = summary.month == _selectedMonth;

            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8.0,
              child: Container(
                width: 60,
                padding: const EdgeInsets.all(6),
                decoration: isSelected
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM \'yy').format(summary.month),
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(summary.totalAmount),
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          reservedSize: 60,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_monthlySummaries.length, (index) {
      final summary = _monthlySummaries[index];
      final isSelected = summary.month == _selectedMonth;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: summary.totalAmount,
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 25,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTransactionList() {
    final groupedTransactions = _groupTransactionsByDate(_displayTransactions);
    return SliverList(
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
    );
  }
}