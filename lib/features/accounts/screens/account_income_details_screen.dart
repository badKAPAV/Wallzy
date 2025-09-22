import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

import 'add_edit_account_screen.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalIncome; // Mapped to Repayments
  final double totalExpense; // Mapped to Purchases

  _MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class AccountIncomeDetailsScreen extends StatefulWidget {
  final Account account;

  const AccountIncomeDetailsScreen({super.key, required this.account});

  @override
  State<AccountIncomeDetailsScreen> createState() =>
      _AccountIncomeDetailsScreenState();
}

class _AccountIncomeDetailsScreenState
    extends State<AccountIncomeDetailsScreen> {
  List<TransactionModel> _accountTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxAmount = 0;
  double _maxIncome = 0; // Max Repayment
  double _maxExpense = 0; // Max Purchase
  double _meanIncome = 0; // Mean Repayment
  double _meanExpense = 0; // Mean Purchase
  double _totalCreditDue = 0;

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

    // Calculate total due for the entire account history
    double totalDue = 0;
    for (final tx in _accountTransactions) {
      if (tx.category == 'Credit Repayment') {
        // Repayments (from any type) decrease the due amount.
        totalDue -= tx.amount;
      } else if (tx.type == 'expense') {
        // Regular purchases increase the due amount.
        totalDue += tx.amount;
      } else if (tx.type == 'income') { // This handles refunds
        totalDue -= tx.amount;
      }
    }

    final summaries = groupedByMonth.entries.map((entry) {
      double purchases = 0;
      double repayments = 0;
      for (var tx in entry.value) {
        if (tx.category == 'Credit Repayment') {
          repayments += tx.amount;
        } else if (tx.type == 'expense') {
          purchases += tx.amount;
        } else if (tx.type == 'income') { // Refunds
          repayments += tx.amount;
        }
      }
      return _MonthlySummary(
        month: entry.key,
        totalIncome: repayments, // Mapped to 'income' for chart reuse
        totalExpense: purchases, // Mapped to 'expense' for chart reuse
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b); // Max Repayment
      _maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b); // Max Purchase
      _maxAmount = _maxIncome > _maxExpense ? _maxIncome : _maxExpense;

      final totalRepaymentSum =
          summaries.fold<double>(0.0, (sum, s) => sum + s.totalIncome);
      _meanIncome = totalRepaymentSum / summaries.length; // Mean Repayment

      final totalPurchaseSum =
          summaries.fold<double>(0.0, (sum, s) => sum + s.totalExpense);
      _meanExpense = totalPurchaseSum / summaries.length; // Mean Purchase
    }

    setState(() {
      _totalCreditDue = totalDue;
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
            'Are you sure you want to delete the account "${account.bankName}"? This will not affect existing transactions linked to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Provider.of<AccountProvider>(context, listen: false)
                  .deleteAccount(account.id);
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
    Provider.of<AccountProvider>(context, listen: false)
        .setPrimaryAccount(widget.account.id);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

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
          Builder(builder: (context) {
            final isCashAccount =
                widget.account.bankName.toLowerCase() == 'cash';
            final canSetPrimary = !widget.account.isPrimary;

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
                      value: 'primary', child: Text('Set as Primary')),
                if (!isCashAccount)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!isCashAccount)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            );
          }),
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
                '${_displayTransactions.length} Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions for this account in the selected period.',
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
                        'Mean (Paid)',
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
                        'Mean (Used)',
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
                    BarChart(_buildBarChartData(currencyFormat)),
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
            if (!showLabels) return const SizedBox.shrink();
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
                          color: Theme.of(context).colorScheme.primaryContainer,
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(summary.totalIncome), // Repayments
                        style: TextStyle(color: appColors.income, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(summary.totalExpense), // Purchases
                        style: TextStyle(color: appColors.expense, fontSize: 10),
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
          BarChartRodData(
            toY: summary.totalExpense, // Purchases
            color: isSelected
                ? appColors.expense
                : appColors.expense.withOpacity(0.3),
            width: 25,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  // ✨ REPLACED: This is the new, more visual summary card
Widget _buildSummaryCard() {
  final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final textTheme = Theme.of(context).textTheme;
  final colors = Theme.of(context).colorScheme;
  final appColors = Theme.of(context).extension<AppColors>()!;

  final selectedSummary = _monthlySummaries
      .firstWhereOrNull((summary) => summary.month == _selectedMonth);

  if (selectedSummary == null) return const SizedBox.shrink();

  final limit = widget.account.creditLimit ?? 0;
  // Handle case where limit is 0 to avoid division by zero
  final utilization = (limit > 0) ? _totalCreditDue / limit : 0.0;
  final availableCredit = limit > 0 ? limit - _totalCreditDue : 0;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Summary', // More general title
              style: textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            
            // ✨ NEW: Visual Progress Bar for Credit Utilization
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available: ${currencyFormat.format(availableCredit)}', style: textTheme.bodyMedium),
                Text('Limit: ${currencyFormat.format(limit)}', style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: utilization,
                minHeight: 12,
                backgroundColor: colors.primaryContainer.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1),
            ),

            // ✨ NEW: Simplified Monthly Stats with Visual Cues
            Text(
              'Activity for ${DateFormat('MMMM yyyy').format(_selectedMonth!)}',
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _VisualMetricItem(
                    label: 'Spent',
                    value: selectedSummary.totalExpense,
                    color: appColors.expense,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _VisualMetricItem(
                    label: 'Paid',
                    value: selectedSummary.totalIncome,
                    color: appColors.income,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ✨ NEW: Add this helper widget to your file


  Widget _buildMetricItem({required String label, required double value}) {
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Text(
          currencyFormat.format(value),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    final groupedTransactions = _groupTransactionsByDate(_displayTransactions);
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
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
      }, childCount: groupedTransactions.length),
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

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
    List<TransactionModel> transactions,
  ) {
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
}

class _VisualMetricItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _VisualMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              currencyFormat.format(value),
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}