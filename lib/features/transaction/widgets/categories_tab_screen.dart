import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/category_transactions_screen.dart';

// Data model for category summary
class CategorySummary {
  final String name;
  final double totalAmount;
  final int transactionCount;
  final String type; // 'income' or 'expense'

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
  // State for filters
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String _selectedType = 'expense'; // 'expense' or 'income'
  List<int> _availableYears = [];

  // State for data
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
      endDate: range.end.add(const Duration(days: 1)),
    );

    final result = provider.getFilteredResults(filter); // This gets all txs in range

    // For category analysis, exclude internal transfers like 'Transfer' and 'Credit Repayment'.
    final analysisTransactions = result.transactions.where((tx) {
      final isInternal =
          tx.category == 'Transfer' || tx.category == 'Credit Repayment';
      return !isInternal;
    }).toList();

    final summaries = _calculateCategorySummaries(analysisTransactions);

    // The provider's totals are inflated by debit-to-debit transfers. We correct this
    // by finding the amount of such transfers and subtracting it.
    double debitToDebitTransfers = 0;
    for (var tx in result.transactions) {
      // Find the 'income' side of a debit-to-debit transfer to know how much to subtract.
      if (tx.type == 'income' && tx.category == 'Transfer') {
        debitToDebitTransfers += tx.amount;
      }
    }

    // Corrected expense total includes credit repayments but excludes simple transfers.
    final totalExpenseForSelector = result.totalExpense - debitToDebitTransfers;
    // Corrected income total excludes simple transfers.
    final totalIncomeForSelector = result.totalIncome - debitToDebitTransfers;

    setState(() {
      _filterResult = FilterResult(transactions: result.transactions, totalExpense: totalExpenseForSelector, totalIncome: totalIncomeForSelector);
      _categorySummaries = summaries;
    });
  }

  Map<String, CategorySummary> _calculateCategorySummaries(
      List<TransactionModel> transactions) {
    // The key will be a composite: "categoryName_type" e.g., "People_income"
    final Map<String, List<TransactionModel>> groupedByCategoryAndType = {};
    for (var tx in transactions) {
      final key = '${tx.category}_${tx.type}';
      (groupedByCategoryAndType[key] ??= []).add(tx);
    }

    final Map<String, CategorySummary> summaries = {};
    groupedByCategoryAndType.forEach((key, txList) {
      final total = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      // The first transaction is safe to use here because we've already grouped by type.
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

  @override
  Widget build(BuildContext context) {
    if (_filterResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentTypeSummaries = _categorySummaries.values
        .where((s) => s.type == _selectedType)
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final totalForPieChart = currentTypeSummaries.fold<double>(
        0.0, (sum, summary) => sum + summary.totalAmount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _DateFilterHeader(
            label: _getFilterLabel(),
            onTap: _showDateFilterModal,
          ),
        ),
        SliverToBoxAdapter(
          child: _PieChartSection(
            summaries: currentTypeSummaries,
            totalAmount: totalForPieChart,
          ),
        ),
        SliverToBoxAdapter(
          child: _TypeSelector(
            selectedType: _selectedType,
            totalExpense: _filterResult!.totalExpense,
            totalIncome: _filterResult!.totalIncome,
            onTypeSelected: (type) {
              setState(() {
                _selectedType = type;
              });
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'All ${_selectedType == 'expense' ? 'Expense' : 'Income'} Categories',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (currentTypeSummaries.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No ${_selectedType} transactions found for this period.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final summary = currentTypeSummaries[index];
                return _CategoryCard(
                  summary: summary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryTransactionsScreen(
                          categoryName: summary.name,
                          categoryType: summary.type,
                          initialSelectedDate: DateTime(_selectedYear,
                              _selectedMonth ?? DateTime.now().month),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: currentTypeSummaries.length,
            ),
          ),
      ],
    );
  }
}

// --- UI Widgets ---

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
              Text('Stats for', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(
                width: 4,
              ),
              Icon(Icons.arrow_drop_down,
                  size: 16, color: Theme.of(context).colorScheme.primary)
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartSection extends StatelessWidget {
  final List<CategorySummary> summaries;
  final double totalAmount;

  const _PieChartSection({required this.summaries, required this.totalAmount});

  Color _getColorForCategory(String category) {
    final hash = category.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(255, (r + 100) % 256, (g + 100) % 256, (b + 100) % 256);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final hasData = summaries.isNotEmpty && totalAmount > 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: hasData
                    ? PieChart(
                        PieChartData(
                          sections: summaries.map((summary) {
                            final percentage =
                                (summary.totalAmount / totalAmount) * 100;
                            return PieChartSectionData(
                              value: percentage,
                              color: _getColorForCategory(summary.name),
                              title: '',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2)
                                ],
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      )
                    : const Center(child: Text("No data")),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: hasData
                    ? Padding(
                      padding: EdgeInsets.all(0),
                      // padding: const EdgeInsets.only(top: 30.0),
                      child: ListView.builder(
                        shrinkWrap: true,
                          itemCount: summaries.length,
                          itemBuilder: (context, index) {
                            final summary = summaries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getColorForCategory(summary.name),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      summary.name,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currencyFormat.format(summary.totalAmount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selectedType;
  final double totalIncome;
  final double totalExpense;
  final ValueChanged<String> onTypeSelected;

  const _TypeSelector({
    required this.selectedType,
    required this.totalIncome,
    required this.totalExpense,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'Expense',
              amount: totalExpense,
              isSelected: selectedType == 'expense',
              onTap: () => onTypeSelected('expense'),
              color: Theme.of(context).extension<AppColors>()!.expense,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _TypeButton(
              label: 'Income',
              amount: totalIncome,
              isSelected: selectedType == 'income',
              onTap: () => onTypeSelected('income'),
              color: Theme.of(context).extension<AppColors>()!.income,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final double amount;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeButton({
    required this.label,
    required this.amount,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = label == 'Income' ? Icons.call_received : Icons.arrow_outward;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Padding(padding: EdgeInsetsGeometry.all(6), child: Icon(icon, color: color, size: 24,),),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? color : theme.colorScheme.onSurface.withAlpha(180),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(amount),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: isSelected ? color : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategorySummary summary;
  final VoidCallback onTap;

  const _CategoryCard({required this.summary, required this.onTap});

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_menu;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'transport':
        return Icons.directions_car_filled_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'salary':
        return Icons.work_outline;
      case 'people':
        return Icons.people_outline;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isExpense = summary.type == 'expense';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: colorScheme.surface.withAlpha(200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary.withAlpha(30),
                child: Icon(
                  _getIconForCategory(summary.name),
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.transactionCount} Transactions',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(summary.totalAmount),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExpense
                      ? Theme.of(context).extension<AppColors>()!.expense
                      : Theme.of(context).extension<AppColors>()!.income,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Note: _DateFilterModal and _FilterItem are copied from transactions_tab_screen.dart
// to be self-contained. In a larger app, they would be shared widgets.

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
                    Text(
                        'Select a month or deselect it to view transactions for the whole year.',
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodySmall)
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onApply(_tempYear, _tempMonth);
                  Navigator.pop(context);
                },
                child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(30)),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Text('Done', style: TextStyle(color: Colors.white)),
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