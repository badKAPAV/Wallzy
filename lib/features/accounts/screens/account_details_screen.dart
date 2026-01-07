import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

import 'add_edit_account_screen.dart';

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

class AccountDetailsScreen extends StatefulWidget {
  final Account account;

  const AccountDetailsScreen({super.key, required this.account});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  List<TransactionModel> _accountTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxAmount = 0;
  double _maxIncome = 0;
  double _maxExpense = 0;
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
    _accountTransactions = allTransactions
        .where((tx) => tx.accountId == widget.account.id)
        .toList();

    if (_accountTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
      });
    }
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _accountTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _accountTransactions,
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
      _maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b);
      _maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b);
      _maxAmount = _maxIncome > _maxExpense ? _maxIncome : _maxExpense;

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
        _selectMonth(_monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete the account "${account.bankName}"? This will not affect existing transactions linked to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Provider.of<AccountProvider>(
                context,
                listen: false,
              ).deleteAccount(account.id);
              Navigator.pop(context); // close details screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAccountScreen(account: widget.account),
      ),
    );
  }

  void _onDelete() {
    _showDeleteConfirmation(context, widget.account);
  }

  void _onSetPrimary() {
    Provider.of<AccountProvider>(
      context,
      listen: false,
    ).setPrimaryAccount(widget.account.id);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
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
            Text(widget.account.bankName),
            const SizedBox(height: 4),
            Text(
              widget.account.accountNumber,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final isCashAccount =
                  widget.account.bankName.toLowerCase() == 'cash';
              final canSetPrimary = !widget.account.isPrimary;

              // Hide menu if there are no available actions
              if (!canSetPrimary && isCashAccount) {
                return const SizedBox.shrink();
              }

              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'primary') _onSetPrimary();
                  if (value == 'edit') _onEdit();
                  if (value == 'delete') _onDelete();
                },
                itemBuilder: (ctx) => [
                  if (canSetPrimary)
                    const PopupMenuItem(
                      value: 'primary',
                      child: Text('Set as Primary'),
                    ),
                  if (!isCashAccount)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!isCashAccount)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                // Changed to show total transactions for the month
                _selectedMonth != null
                    ? '${_displayTransactions.length} Transactions in ${DateFormat('MMMM').format(_selectedMonth!)}'
                    : 'Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyReportPlaceholder(
                message:
                    "No transactions for this account in the selected period.",
                icon: HugeIcons.strokeRoundedInvoice01,
              ),
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
    final double chartWidth =
        _monthlySummaries.length * (barWidth + barSpacing) + 40;
    final appColors = Theme.of(context).extension<AppColors>()!;

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
                  Text(
                    'Max\n${currencyFormat.format(_maxAmount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mean (Inc)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.income,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.expense,
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
                height: 280,
                child: Stack(
                  children: [
                    // Bar chart for expenses
                    BarChart(_buildBarChartData(currencyFormat)),
                    // Line chart for income, overlaid
                    LineChart(_buildLineChartData(currencyFormat)),
                  ],
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

  BarChartData _buildBarChartData(NumberFormat currencyFormat) {
    return BarChartData(
      maxY: _maxAmount == 0 ? 1 : _maxAmount * 1.2,
      barTouchData: _buildBarTouchData(),
      titlesData: _buildTitlesData(currencyFormat),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      barGroups: _buildBarGroups(context),
      alignment: BarChartAlignment.spaceAround,
    );
  }

  LineChartData _buildLineChartData(NumberFormat currencyFormat) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return LineChartData(
      minY: 0,
      maxY: _maxAmount == 0 ? 1 : _maxAmount * 1.2,
      minX: 0,
      maxX: _monthlySummaries.length.toDouble(),
      gridData: const FlGridData(show: false),
      titlesData: _buildTitlesData(currencyFormat, showLabels: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(_monthlySummaries.length, (index) {
            final summary = _monthlySummaries[index];
            return FlSpot(index.toDouble() + 0.5, summary.totalIncome);
          }),
          isCurved: true,
          color: appColors.income,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }

  FlTitlesData _buildTitlesData(
    NumberFormat currencyFormat, {
    bool showLabels = true,
  }) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            if (!showLabels) {
              return const SizedBox.shrink();
            }
            final index = value.toInt();
            if (index < 0 || index >= _monthlySummaries.length) {
              return const SizedBox();
            }

            final summary = _monthlySummaries[index];
            final isSelected = summary.month == _selectedMonth;

            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 12.0,
              child: GestureDetector(
                onTap: () => _selectMonth(summary.month),
                child: AnimatedContainer(
                  width: 70,
                  padding: const EdgeInsets.all(6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  duration: const Duration(milliseconds: 200),
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
                        style: TextStyle(color: appColors.income, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(summary.totalExpense),
                        style: TextStyle(
                          color: appColors.expense,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          reservedSize: 77,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return List.generate(_monthlySummaries.length, (index) {
      final summary = _monthlySummaries[index];
      final isSelected = summary.month == _selectedMonth;
      return BarChartGroupData(
        x: index,
        barRods: [
          // Expense Bar
          BarChartRodData(
            toY: summary.totalExpense,
            color: isSelected
                ? appColors.expense
                : appColors.expense.withAlpha(80),
            width: 25,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _buildSummaryCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final appColors = Theme.of(context).extension<AppColors>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selectedSummary = _monthlySummaries.firstWhereOrNull(
      (summary) => summary.month == _selectedMonth,
    );

    if (selectedSummary == null) {
      return const SizedBox.shrink();
    }

    final income = selectedSummary.totalIncome;
    final expense = selectedSummary.totalExpense;
    final balance = income - expense;
    final totalVolume = income + expense;

    // Calculate flex ratios for the bar
    // If total volume is 0, we avoid division by zero.
    final int incomeFlex = totalVolume == 0
        ? 0
        : ((income / totalVolume) * 100).toInt();
    final int expenseFlex = totalVolume == 0
        ? 0
        : ((expense / totalVolume) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Using surfaceContainer for distinct card look
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MONTHLY OVERVIEW",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Hero Net Balance
            Text(
              "Net Balance",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currencyFormat.format(balance),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: balance >= 0 ? appColors.income : appColors.expense,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 24),

            // 3. Visual Ratio Bar (Separate Containers)
            if (totalVolume > 0)
              SizedBox(
                height: 12,
                child: Row(
                  children: [
                    // Income Bar
                    if (incomeFlex > 0)
                      Expanded(
                        flex: incomeFlex,
                        child: Container(
                          decoration: BoxDecoration(
                            color: appColors.income,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    // Gap (Only show if both exist)
                    if (incomeFlex > 0 && expenseFlex > 0)
                      const SizedBox(width: 6),
                    // Expense Bar
                    if (expenseFlex > 0)
                      Expanded(
                        flex: expenseFlex,
                        child: Container(
                          decoration: BoxDecoration(
                            color: appColors.expense,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            if (totalVolume > 0) const SizedBox(height: 20),

            // 4. Detailed Numbers
            Row(
              children: [
                // Income Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.income,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "INCOME",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(income),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 30,
                  width: 1,
                  color: colors.outlineVariant.withOpacity(0.5),
                ),
                const SizedBox(width: 24),
                // Expense Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.expense,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "EXPENSE",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(expense),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  // _groupTransactionsByDate removed
}
