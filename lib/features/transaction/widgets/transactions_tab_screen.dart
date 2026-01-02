import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';

// RE-USE WIDGETS FROM CATEGORIES TAB (In a real app these go in a shared file)
// We assume _DateFilterPill and _DateFilterModal are the same design as above.
// For self-containment, the minimal versions are re-implemented below with the new design.

class TransactionsTabScreen extends StatefulWidget {
  const TransactionsTabScreen({super.key});

  @override
  State<TransactionsTabScreen> createState() => TransactionsTabScreenState();
}

class TransactionsTabScreenState extends State<TransactionsTabScreen> {
  // --- LOGIC (UNCHANGED) ---
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    if (allTransactions.isNotEmpty) {
      final years = allTransactions
          .map((tx) => tx.timestamp.year)
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a));
      _availableYears = years;
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    } else {
      _availableYears = [_selectedYear];
    }
  }

  DateTimeRange _getFilterRange() {
    if (_selectedMonth != null) {
      final firstDay = DateTime(_selectedYear, _selectedMonth!, 1);
      final lastDay = (_selectedMonth == 12)
          ? DateTime(_selectedYear + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(
              _selectedYear,
              _selectedMonth! + 1,
              1,
            ).subtract(const Duration(days: 1));
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

  // Helper to fetch stats for the modal (Net Balance for Transactions Tab)
  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );
    Map<int, String> stats = {};
    for (int month = 1; month <= 12; month++) {
      final range = DateTimeRange(
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
      );
      final filter = TransactionFilter(
        startDate: range.start,
        endDate: range.end.add(const Duration(days: 1)),
      );
      final result = provider.getFilteredResults(filter);
      // Show net balance if there is activity
      if (result.transactions.isNotEmpty) {
        stats[month] = currencyFormat.format(result.balance);
      }
    }
    return stats;
  }

  void _showDateFilterModal() {
    showDateFilterModal(
      context: context,
      availableYears: _availableYears,
      initialYear: _selectedYear,
      initialMonth: _selectedMonth,
      onApply: (year, month) {
        setState(() {
          _selectedYear = year;
          _selectedMonth = month;
        });
      },
      onStatsRequired: _fetchMonthlyStats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final range = _getFilterRange();
    final filter = TransactionFilter(
      startDate: range.start,
      endDate: range.end.add(const Duration(days: 1)),
    );
    final result = transactionProvider.getFilteredResults(filter);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Floating Pill
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: DateFilterPill(
                label: _getFilterLabel(),
                onTap: _showDateFilterModal,
              ),
            ),
          ),
        ),

        // 2. Net Flow Dashboard
        SliverToBoxAdapter(child: _NetFlowDashboard(result: result)),

        // 3. List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Text(
              'ACTIVITY FEED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),

        // 4. List
        if (result.transactions.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          GroupedTransactionList(
            transactions: result.transactions,
            onTap: (tx) => _showTransactionDetails(context, tx),
            useSliver: true,
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }
}

// --- REDESIGNED WIDGETS ---

class _NetFlowDashboard extends StatelessWidget {
  final FilterResult result;
  const _NetFlowDashboard({required this.result});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final total = result.totalIncome + result.totalExpense;
    final incomePercent = total > 0
        ? (result.totalIncome.toDouble() / total) * 100
        : 0.0;
    final expensePercent = total > 0
        ? (result.totalExpense.toDouble() / total) * 100
        : 0.0;

    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 100,
                width: 100,
                child: PieChart(
                  PieChartData(
                    sections: (total > 0)
                        ? [
                            PieChartSectionData(
                              value: incomePercent,
                              color: appColors.income,
                              radius: 12,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: expensePercent,
                              color: appColors.expense,
                              radius: 12,
                              showTitle: false,
                            ),
                          ]
                        : [
                            PieChartSectionData(
                              value: 100,
                              color: theme.colorScheme.surfaceContainerHighest,
                              radius: 12,
                              showTitle: false,
                            ),
                          ],
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Balance Big Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Net Balance",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      currencyFormat.format(result.balance),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Flow Rows
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FlowStat(
                    label: "In",
                    amount: result.totalIncome,
                    color: appColors.income,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _FlowStat(
                    label: "Out",
                    amount: result.totalExpense,
                    color: appColors.expense,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _FlowStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Re-implementing the Pill and Modal locally to ensure self-containment for this file
// [Deleted local classes]

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('Nothing here', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
