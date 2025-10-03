import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/people/screens/person_transactions_screen.dart';

// Data model for person summary
class PersonSummary {
  final Person person;
  final double totalAmount;
  final int transactionCount;
  final String type; // 'income' or 'expense'

  PersonSummary({
    required this.person,
    required this.totalAmount,
    required this.transactionCount,
    required this.type,
  });
}

class PaymentsView extends StatelessWidget {
  const PaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentsAnalysisScreen();
  }
}

class PaymentsAnalysisScreen extends StatefulWidget {
  const PaymentsAnalysisScreen({super.key});

  @override
  State<PaymentsAnalysisScreen> createState() => _PaymentsAnalysisScreenState();
}

class _PaymentsAnalysisScreenState extends State<PaymentsAnalysisScreen> {
  // State for filters
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String _selectedType = 'expense'; // 'expense' or 'income'
  List<int> _availableYears = [];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions = Provider.of<TransactionProvider>(context, listen: false).transactions;
    setState(() {
      final years =
          allTransactions.map((tx) => tx.timestamp.year).toSet().toList();
      if (years.isNotEmpty) {
        years.sort((a, b) => b.compareTo(a));
        _availableYears = years;
        if (!_availableYears.contains(_selectedYear)) {
          _selectedYear = _availableYears.first;
        }
      } else {
        _availableYears = [_selectedYear];
      }
    });
  }
  Map<String, PersonSummary> _calculatePersonSummaries(
      List<TransactionModel> transactions) {
    // Use a temporary map to build summaries. Key: "personId_type"
    final Map<String, PersonSummary> tempSummaries = {};

    for (var tx in transactions) {
      for (var person in tx.people ?? <Person>[]) {
        final key = '${person.id}_${tx.type}';
        final existing = tempSummaries[key];

        tempSummaries[key] = PersonSummary(
          person: person,
          totalAmount: (existing?.totalAmount ?? 0) + tx.amount,
          transactionCount: (existing?.transactionCount ?? 0) + 1,
          type: tx.type,
        );
      }
    }
    return tempSummaries;
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
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        final range = _getFilterRange();
        final peopleTransactions = transactionProvider.transactions.where((tx) {
          final txDate = tx.timestamp;
          // A "people" transaction is one that has at least one person associated with it.
          return (tx.people?.isNotEmpty ?? false) &&
              txDate.isAfter(range.start.subtract(const Duration(microseconds: 1))) &&
              txDate.isBefore(range.end.add(const Duration(days: 1)));
        }).toList();

        final personSummaries = _calculatePersonSummaries(peopleTransactions);
        final totalExpense = personSummaries.values
            .where((s) => s.type == 'expense')
            .fold<double>(0.0, (sum, s) => sum + s.totalAmount);
        final totalIncome = personSummaries.values
            .where((s) => s.type == 'income')
            .fold<double>(0.0, (sum, s) => sum + s.totalAmount);

        final currentTypeSummaries = personSummaries.values
            .where((s) => s.type == _selectedType)
            .toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DateFilterHeader(
                label: _getFilterLabel(),
                onTap: _showDateFilterModal,
              ),
            ),
            SliverToBoxAdapter(
              child: _PieChartSection(summaries: currentTypeSummaries),
            ),
            SliverToBoxAdapter(
              child: _TypeSelector(
                selectedType: _selectedType,
                totalExpense: totalExpense,
                totalIncome: totalIncome,
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
                  'All ${_selectedType == 'expense' ? 'Payments Made' : 'Payments Received'}',
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
                      'No transactions with people found for this period.',
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
                    return _PersonCard(
                      summary: summary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonTransactionsScreen(
                              person: summary.person,
                              transactionType: summary.type,
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
      },
    );
  }
}

// --- UI Widgets (many are copied/adapted from categories_tab_screen.dart) ---
// In a real app, these would be refactored into common, reusable widgets.

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
              const SizedBox(width: 4),
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
  final List<PersonSummary> summaries;

  const _PieChartSection({required this.summaries});

  Color _getColorForPerson(String name) {
    final hash = name.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(255, (r + 100) % 256, (g + 100) % 256, (b + 100) % 256);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final totalAmount = summaries.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
    final hasData = summaries.isNotEmpty && totalAmount > 0;

    final List<MapEntry<String, double>> chartDataEntries = [];
    if (hasData) {
      // Always show all individual persons in the chart data entries
      chartDataEntries.addAll(summaries.map((s) => MapEntry(s.person.fullName, s.totalAmount)));
    }

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
                          sections: chartDataEntries.map((entry) {
                            return PieChartSectionData(
                              value: entry.value,
                              color: _getColorForPerson(entry.key),
                              title: '',
                              radius: 50,
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
                    ? ListView.builder(
                        shrinkWrap: true,
                        itemCount: chartDataEntries.length,
                        itemBuilder: (context, index) {
                          final entry = chartDataEntries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getColorForPerson(entry.key),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  currencyFormat.format(entry.value),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
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
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? color
                        : theme.colorScheme.onSurface.withAlpha(180),
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

class _PersonCard extends StatelessWidget {
  final PersonSummary summary;
  final VoidCallback onTap;

  const _PersonCard({required this.summary, required this.onTap});

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
                child: Text(
                  summary.person.fullName.isNotEmpty
                      ? summary.person.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.person.fullName, style: textTheme.titleMedium),
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

  @override
  void initState() {
    super.initState();
    _tempYear = widget.initialYear;
    _tempMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: months.entries.map((entry) {
                return _FilterItem(
                  label: entry.key,
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
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterItem({
    required this.label,
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
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}