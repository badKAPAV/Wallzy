import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/category_transactions_screen.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';

// Data model for category summary (Kept as is)
class CategorySummary {
  final String name;
  final double totalAmount;
  final int transactionCount;
  final String type;

  CategorySummary({
    required this.name,
    required this.totalAmount,
    required this.transactionCount,
    required this.type,
  });
}

class CategoriesTabScreen extends StatefulWidget {
  const CategoriesTabScreen({super.key});

  @override
  State<CategoriesTabScreen> createState() => _CategoriesTabScreenState();
}

class _CategoriesTabScreenState extends State<CategoriesTabScreen> {
  // --- LOGIC SECTION (UNCHANGED) ---
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String _selectedType = 'expense';
  List<int> _availableYears = [];
  FilterResult? _filterResult;
  Map<String, CategorySummary> _categorySummaries = {};

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
    _runFilter();
  }

  void _runFilter() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final range = _getFilterRange();
    final filter = TransactionFilter(
      startDate: range.start,
      endDate: range.end.add(const Duration(days: 1)),
    );
    final result = provider.getFilteredResults(filter);

    final analysisTransactions = result.transactions.where((tx) {
      final isInternal =
          tx.category == 'Transfer' || tx.category == 'Credit Repayment';
      return !isInternal;
    }).toList();

    final summaries = _calculateCategorySummaries(analysisTransactions);

    double debitToDebitTransfers = 0;
    for (var tx in result.transactions) {
      if (tx.type == 'income' && tx.category == 'Transfer') {
        debitToDebitTransfers += tx.amount;
      }
    }

    final totalExpenseForSelector = result.totalExpense - debitToDebitTransfers;
    final totalIncomeForSelector = result.totalIncome - debitToDebitTransfers;

    setState(() {
      _filterResult = FilterResult(
        transactions: result.transactions,
        totalExpense: totalExpenseForSelector,
        totalIncome: totalIncomeForSelector,
      );
      _categorySummaries = summaries;
    });
  }

  Map<String, CategorySummary> _calculateCategorySummaries(
    List<TransactionModel> transactions,
  ) {
    final Map<String, List<TransactionModel>> groupedByCategoryAndType = {};
    for (var tx in transactions) {
      final key = '${tx.category}_${tx.type}';
      (groupedByCategoryAndType[key] ??= []).add(tx);
    }

    final Map<String, CategorySummary> summaries = {};
    groupedByCategoryAndType.forEach((key, txList) {
      final total = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final firstTx = txList.first;
      summaries[key] = CategorySummary(
        name: firstTx.category,
        totalAmount: total,
        transactionCount: txList.length,
        type: firstTx.type,
      );
    });
    return summaries;
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

  // Helper to fetch stats for the modal
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
        type: 'expense', // Categories tab primarily shows expense breakdown
      );
      final result = provider.getFilteredResults(filter);
      if (result.totalExpense > 0) {
        stats[month] = currencyFormat.format(result.totalExpense);
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
        _runFilter();
      },
      onStatsRequired: _fetchMonthlyStats,
    );
  }

  // --- REDESIGNED BUILD ---

  @override
  Widget build(BuildContext context) {
    if (_filterResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentTypeSummaries =
        _categorySummaries.values.where((s) => s.type == _selectedType).toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final totalForPieChart = currentTypeSummaries.fold<double>(
      0.0,
      (sum, summary) => sum + summary.totalAmount,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Floating Date Pill
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

        // 2. Dashboard Pod (Chart)
        SliverToBoxAdapter(
          child: _ChartDashboardPod(
            summaries: currentTypeSummaries,
            totalAmount: totalForPieChart,
            selectedType: _selectedType,
          ),
        ),

        // 3. Segmented Type Selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: _SegmentedTypeSelector(
              selectedType: _selectedType,
              totalExpense: _filterResult!.totalExpense,
              totalIncome: _filterResult!.totalIncome,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
            ),
          ),
        ),

        // 4. List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'BREAKDOWN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),

        // 5. Category List
        if (currentTypeSummaries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final summary = currentTypeSummaries[index];
              return _FunkyCategoryTile(
                summary: summary,
                totalForPeriod: totalForPieChart,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryTransactionsScreen(
                        categoryName: summary.name,
                        categoryType: summary.type,
                        initialSelectedDate: DateTime(
                          _selectedYear,
                          _selectedMonth ?? DateTime.now().month,
                        ),
                      ),
                    ),
                  );
                },
              );
            }, childCount: currentTypeSummaries.length),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// --- REDESIGNED WIDGETS ---

// Shared date filter widgets moved to lib/common/widgets/date_filter_selector.dart

class _ChartDashboardPod extends StatelessWidget {
  final List<CategorySummary> summaries;
  final double totalAmount;
  final String selectedType;

  const _ChartDashboardPod({
    required this.summaries,
    required this.totalAmount,
    required this.selectedType,
  });

  Color _getColorForCategory(String category) {
    final hash = category.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(
      255,
      (r + 100) % 256,
      (g + 100) % 256,
      (b + 100) % 256,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );
    final hasData = summaries.isNotEmpty && totalAmount > 0;
    final theme = Theme.of(context);

    // Show top 4 categories in legend
    final topSummaries = summaries.take(4).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: hasData
                ? PieChart(
                    PieChartData(
                      sections: summaries.map((summary) {
                        final percentage =
                            (summary.totalAmount / totalAmount) * 100;
                        return PieChartSectionData(
                          value: percentage,
                          color: _getColorForCategory(summary.name),
                          radius: 25,
                          showTitle: false,
                        );
                      }).toList(),
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                    ),
                  )
                : Center(
                    child: Text(
                      "No Data",
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          // Legend Grid
          if (hasData)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: topSummaries.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForCategory(s.name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currencyFormat.format(s.totalAmount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _SegmentedTypeSelector extends StatelessWidget {
  final String selectedType;
  final double totalIncome;
  final double totalExpense;
  final ValueChanged<String> onTypeSelected;

  const _SegmentedTypeSelector({
    required this.selectedType,
    required this.totalIncome,
    required this.totalExpense,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: "Expense",
            amount: totalExpense,
            isSelected: selectedType == 'expense',
            onTap: () => onTypeSelected('expense'),
          ),
          _SegmentButton(
            label: "Income",
            amount: totalIncome,
            isSelected: selectedType == 'income',
            onTap: () => onTypeSelected('income'),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final double amount;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final isExpense = label.toLowerCase() == 'expense';

    final icon = isExpense ? Icons.call_made : Icons.call_received;

    final iconColor = isExpense ? Colors.red : Colors.green;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isExpense
                      ? Colors.red.withAlpha(60)
                      : Colors.green.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
}

class _FunkyCategoryTile extends StatelessWidget {
  final CategorySummary summary;
  final double totalForPeriod;
  final VoidCallback onTap;

  const _FunkyCategoryTile({
    required this.summary,
    required this.totalForPeriod,
    required this.onTap,
  });

  IconData _getIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food')) return Icons.lunch_dining_rounded;
    if (c.contains('shop')) return Icons.shopping_bag_rounded;
    if (c.contains('transport')) return Icons.directions_car_rounded;
    if (c.contains('bill')) return Icons.receipt_long_rounded;
    if (c.contains('entertainment')) return Icons.movie_filter_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final percentage = (summary.totalAmount / totalForPeriod);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Icon Bubble
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIcon(summary.name),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          summary.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          currencyFormat.format(summary.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 6,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: summary.type == 'expense'
                                  ? theme.extension<AppColors>()!.expense
                                  : theme.extension<AppColors>()!.income,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${(percentage * 100).toStringAsFixed(1)}%",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${summary.transactionCount} transactions",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SHARED MODAL (Logic Unchanged, Visuals Updated) ---
