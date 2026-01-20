import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';

// --- MAIN SCREEN ---

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
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      return BudgetCycleHelper.getCycleRange(
        targetMonth: _selectedMonth!,
        targetYear: _selectedYear,
        mode: settings.budgetCycleMode,
        startDay: settings.budgetCycleStartDay,
      );
    } else {
      return DateTimeRange(
        start: DateTime(_selectedYear, 1, 1),
        end: DateTime(_selectedYear, 12, 31),
      );
    }
  }

  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final currencySymbol = settings.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    Map<int, String> stats = {};
    for (int month = 1; month <= 12; month++) {
      final range = BudgetCycleHelper.getCycleRange(
        targetMonth: month,
        targetYear: year,
        mode: settings.budgetCycleMode,
        startDay: settings.budgetCycleStartDay,
      );
      final filter = TransactionFilter(
        startDate: range.start,
        endDate: range.end,
      );
      final result = provider.getFilteredResults(filter);
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
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Center(
              child: DateNavigationControl(
                selectedYear: _selectedYear,
                selectedMonth: _selectedMonth,
                onTapPill: _showDateFilterModal,
                onDateChanged: (year, month) {
                  setState(() {
                    _selectedYear = year;
                    _selectedMonth = month;
                  });
                },
              ),
            ),
          ),
        ),

        if (result.transactions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyReportPlaceholder(
              message: "Can't show reports unless you've made transactions",
              icon: HugeIcons.strokeRoundedInvoice01,
            ),
          ),

        if (result.transactions.isNotEmpty) ...[
          // 2. Net Flow Dashboard (Using Custom Engine)
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
          GroupedTransactionList(
            transactions: result.transactions,
            onTap: (tx) => _showTransactionDetails(context, tx),
            useSliver: true,
          ),
        ],

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

// --- UPDATED DASHBOARD WITH CUSTOM CHART ---

class _NetFlowDashboard extends StatelessWidget {
  final FilterResult result;
  const _NetFlowDashboard({required this.result});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final total = result.totalIncome + result.totalExpense;

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
              // --- NEW LEDGR PIE CHART ENGINE ---
              SizedBox(
                height: 100,
                width: 100,
                child: LedgrPieChart(
                  thickness: 14,
                  gap: 24,
                  emptyColor: theme.colorScheme.surfaceContainerHighest
                      .withAlpha(100),
                  sections: (total > 0)
                      ? [
                          PieData(
                            value: result.totalIncome,
                            color: appColors.income,
                          ),
                          PieData(
                            value: result.totalExpense,
                            color: appColors.expense,
                          ),
                        ]
                      : [], // Empty list triggers empty state
                ),
              ),
              const SizedBox(width: 24),

              // --- BALANCE TEXT ---
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

          // --- FLOW ROWS ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
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
