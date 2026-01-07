import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;

  _MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class PersonTransactionsScreen extends StatefulWidget {
  final Person person;
  final DateTime initialSelectedDate;
  final String transactionType; // 'income' or 'expense'

  const PersonTransactionsScreen({
    super.key,
    required this.person,
    required this.initialSelectedDate,
    required this.transactionType,
  });

  @override
  State<PersonTransactionsScreen> createState() =>
      _PersonTransactionsScreenState();
}

class _PersonTransactionsScreenState extends State<PersonTransactionsScreen> {
  List<TransactionModel> _allPersonTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];

  double _maxAmount = 0;
  double _meanIncome = 0;
  double _meanExpense = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndProcessTransactions();
    });
  }

  void _loadAndProcessTransactions() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;

    _allPersonTransactions = allTransactions.where((tx) {
      // Filter for all transactions associated with the specific person.
      final isPersonMatch =
          tx.people?.any((p) => p.id == widget.person.id) ?? false;
      return isPersonMatch;
    }).toList();

    if (_allPersonTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
      });
    }
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _allPersonTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    final summaries = groupedByMonth.entries.map((entry) {
      final income = entry.value
          .where((tx) => tx.type == 'income')
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final expense = entry.value
          .where((tx) => tx.type == 'expense')
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return _MonthlySummary(
        month: entry.key,
        totalIncome: income,
        totalExpense: expense,
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      final maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b);
      final maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b);
      _maxAmount = maxIncome > maxExpense ? maxIncome : maxExpense;

      final totalIncomeSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalIncome,
      );
      _meanIncome = totalIncomeSum / summaries.length;

      final totalExpenseSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalExpense,
      );
      _meanExpense = totalExpenseSum / summaries.length;
    }

    setState(() {
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        final initialMonthDate = DateTime(
          widget.initialSelectedDate.year,
          widget.initialSelectedDate.month,
        );
        final hasDataInInitialMonth = _monthlySummaries.any(
          (s) => s.month == initialMonthDate,
        );

        _selectMonth(
          hasDataInInitialMonth
              ? initialMonthDate
              : _monthlySummaries.last.month,
        );
      } else {
        _displayTransactions = [];
      }
    });
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _allPersonTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.person.fullName),
            const SizedBox(height: 4),
            Text(
              // Use the initial transaction type for the subtitle
              widget.transactionType == 'expense'
                  ? 'Payments Made'
                  : 'Payments Received',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement search functionality within this person's transactions
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                '${_displayTransactions.length} Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions with this person for the selected period.',
                ),
              ),
            )
          else
            _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    // const double barWidth = 20.0;
    // const double barSpacing = 24.0;
    final double chartWidth = _monthlySummaries.length * 60;

    return SizedBox(
      height: 250,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, right: 16),
              child: SizedBox(
                height: 190,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max\n${currencyFormat.format(_maxAmount)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mean (Inc)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).extension<AppColors>()!.income,
                              ),
                        ),
                        Text(
                          currencyFormat.format(_meanIncome),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mean (Exp)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).extension<AppColors>()!.expense,
                              ),
                        ),
                        Text(
                          currencyFormat.format(_meanExpense),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
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
                      groupsSpace: 100,
                      maxY: _maxAmount == 0 ? 1 : _maxAmount * 1.2,
                      barTouchData: _buildBarTouchData(),
                      titlesData: _buildTitlesData(currencyFormat),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: _buildBarGroups(),
                      alignment: BarChartAlignment.spaceAround,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        tooltipPadding: EdgeInsets.zero,
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
            if (index < 0 || index >= _monthlySummaries.length) {
              return const SizedBox();
            }
            final summary = _monthlySummaries[index];
            final isSelected = summary.month == _selectedMonth;

            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8.0,
              child: GestureDetector(
                onTap: () => _selectMonth(summary.month),
                child: Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
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
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(summary.totalIncome),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).extension<AppColors>()!.income,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(summary.totalExpense),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).extension<AppColors>()!.expense,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          reservedSize: 75,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return List.generate(_monthlySummaries.length, (index) {
      final summary = _monthlySummaries[index];
      final isSelected = summary.month == _selectedMonth;
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          // Income Bar
          BarChartRodData(
            toY: summary.totalIncome,
            color: isSelected
                ? appColors.income
                : appColors.income.withValues(alpha: 0.3),
            width: 10,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          // Expense Bar
          BarChartRodData(
            toY: summary.totalExpense,
            color: isSelected
                ? appColors.expense
                : appColors.expense.withValues(alpha: 0.3),
            width: 10,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _buildTransactionList() {
    return GroupedTransactionList(
      transactions: _displayTransactions,
      onTap: (tx) => _showTransactionDetails(context, tx),
      useSliver: true,
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
