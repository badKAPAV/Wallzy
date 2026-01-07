import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/people/screens/person_transactions_screen.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

// --- DATA MODEL (UNCHANGED) ---
class PersonSummary {
  final Person person;
  final double totalAmount;
  final int transactionCount;
  final String type;

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
  Widget build(BuildContext context) => const PaymentsAnalysisScreen();
}

class PaymentsAnalysisScreen extends StatefulWidget {
  const PaymentsAnalysisScreen({super.key});
  @override
  State<PaymentsAnalysisScreen> createState() => _PaymentsAnalysisScreenState();
}

class _PaymentsAnalysisScreenState extends State<PaymentsAnalysisScreen> {
  // --- LOGIC (UNCHANGED) ---
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String _selectedType = 'expense';
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFilters());
  }

  void _initializeFilters() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    setState(() {
      final years = allTransactions
          .map((tx) => tx.timestamp.year)
          .toSet()
          .toList();
      if (years.isNotEmpty) {
        years.sort((a, b) => b.compareTo(a));
        _availableYears = years;
        if (!_availableYears.contains(_selectedYear))
          _selectedYear = _availableYears.first;
      } else {
        _availableYears = [_selectedYear];
      }
    });
  }

  Map<String, PersonSummary> _calculatePersonSummaries(
    List<TransactionModel> transactions,
  ) {
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

  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final allTxs = txProvider.transactions;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    Map<int, String> stats = {};
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      // Filter for transactions involving people
      final monthTotal = allTxs
          .where(
            (tx) =>
                (tx.people?.isNotEmpty ?? false) &&
                tx.timestamp.isAfter(
                  start.subtract(const Duration(seconds: 1)),
                ) &&
                tx.timestamp.isBefore(end),
          )
          .fold(0.0, (sum, tx) => sum + tx.amount);

      if (monthTotal > 0) {
        stats[month] = currencyFormat.format(monthTotal);
      }
    }
    return stats;
  }

  void _showDateFilterModal() {
    HapticFeedback.selectionClick();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeFilters();
  }

  // --- REDESIGNED BUILD ---

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        final range = _getFilterRange();
        final peopleTransactions = transactionProvider.transactions.where((tx) {
          final txDate = tx.timestamp;
          return (tx.people?.isNotEmpty ?? false) &&
              txDate.isAfter(
                range.start.subtract(const Duration(microseconds: 1)),
              ) &&
              txDate.isBefore(range.end.add(const Duration(days: 1)));
        }).toList();

        final personSummaries = _calculatePersonSummaries(peopleTransactions);

        final currentTypeSummaries =
            personSummaries.values
                .where((s) => s.type == _selectedType)
                .toList()
              ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        // Calculate total for chart
        final totalForChart = currentTypeSummaries.fold<double>(
          0.0,
          (sum, s) => sum + s.totalAmount,
        );

        // 1. GLOBAL EMPTY CHECK
        if (personSummaries.isEmpty) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyReportPlaceholder(
                  message: "No payments sent or received in this period",
                  icon: HugeIcons.strokeRoundedUserMultiple02,
                ),
              ),
            ],
          );
        }

        // 2. REGULAR VIEW (Has Data somewhere)
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Floating Date Pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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

            // 2. Chart Dashboard (Only if tab has data)
            if (currentTypeSummaries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentChartPod(
                    summaries: currentTypeSummaries,
                    totalAmount: totalForChart,
                  ),
                ),
              ),

            // 3. Segmented Toggle (Always visible)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: _SegmentedPaymentToggle(
                  selectedType: _selectedType,
                  onTypeSelected: (type) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedType = type);
                  },
                ),
              ),
            ),

            // 4. Content (List or Placeholder)
            if (currentTypeSummaries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyReportPlaceholder(
                  message:
                      "No payments ${_selectedType == 'expense' ? 'sent' : 'received'} in this period",
                  icon: HugeIcons.strokeRoundedUserMultiple02,
                ),
              ),

            if (currentTypeSummaries.isNotEmpty) ...[
              // List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    _selectedType == 'expense'
                        ? 'PAYMENTS MADE'
                        : 'PAYMENTS RECEIVED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),

              // List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final summary = currentTypeSummaries[index];
                  return _FunkyPersonTile(
                    summary: summary,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonTransactionsScreen(
                            person: summary.person,
                            transactionType: summary.type,
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
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}

// --- REDESIGNED WIDGETS ---

class _PaymentChartPod extends StatelessWidget {
  final List<PersonSummary> summaries;
  final double totalAmount;

  const _PaymentChartPod({required this.summaries, required this.totalAmount});

  Color _getColorForPerson(String name) {
    final hash = name.hashCode;
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final hasData = summaries.isNotEmpty && totalAmount > 0;

    // Top 4 for legend
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
            height: 180,
            child: hasData
                ? PieChart(
                    PieChartData(
                      sections: summaries.map((s) {
                        return PieChartSectionData(
                          value: s.totalAmount,
                          color: _getColorForPerson(s.person.fullName),
                          radius: 25,
                          showTitle: false,
                        );
                      }).toList(),
                      sectionsSpace: 4,
                      centerSpaceRadius: 55,
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getColorForPerson(s.person.fullName),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.person.fullName.split(' ').first,
                      style: const TextStyle(
                        fontSize: 12,
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

class _SegmentedPaymentToggle extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _SegmentedPaymentToggle({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final isExpense = selectedType == 'expense';

    return Container(
      height: 56, // Fixed height for alignment
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Background Slide
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            alignment: isExpense ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Buttons
          Row(
            children: [
              _SegmentButtonContent(
                label: "Sent",
                icon: Icons.arrow_outward_rounded,
                selectedColor: appColors.expense,
                isSelected: isExpense,
                onTap: () => onTypeSelected('expense'),
              ),
              _SegmentButtonContent(
                label: "Received",
                icon: Icons.call_received_rounded,
                selectedColor: appColors.income,
                isSelected: !isExpense,
                onTap: () => onTypeSelected('income'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButtonContent extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color selectedColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButtonContent({
    required this.label,
    required this.icon,
    required this.selectedColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? selectedColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunkyPersonTile extends StatelessWidget {
  final PersonSummary summary;
  final VoidCallback onTap;

  const _FunkyPersonTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final isExpense = summary.type == 'expense';
    final amountColor = isExpense
        ? theme.extension<AppColors>()!.expense
        : theme.extension<AppColors>()!.income;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: amountColor.withAlpha(25),
                foregroundColor: amountColor,
                child: Text(
                  summary.person.fullName.isNotEmpty
                      ? summary.person.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.person.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${summary.transactionCount} transactions",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(summary.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
