import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/screens/subscription_details_screen.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

// A view model for a subscription series
class _SubscriptionSummary {
  final Subscription subscription;
  final double totalSpent;
  final int transactionCount;
  final DateTime lastPaymentDate;
  final List<TransactionModel> transactions;
  final double averageAmount;

  _SubscriptionSummary({
    required this.subscription,
    required this.totalSpent,
    required this.transactionCount,
    required this.lastPaymentDate,
    required this.transactions,
    required this.averageAmount,
  });
}

// Data model for subscription summary for the pie chart
class _SubscriptionPieSummary {
  final String name;
  final double totalAmount;

  _SubscriptionPieSummary({
    required this.name,
    required this.totalAmount,
  });
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  // State for filters
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  List<int> _availableYears = [];

  // State for data
  bool _isLoading = true;

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
    // Just trigger a rebuild, the build method will do the filtering.
    setState(() {
      _isLoading = false;
    });
  }

  void _runFilter() {
    // This method is called by the modal to trigger a rebuild.
    setState(() {});
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

  List<_SubscriptionSummary> _processSubscriptions(
      List<Subscription> subscriptions, List<TransactionModel> allTransactions) {
    final summaries = subscriptions.map((sub) {
      final txsForSub =
          allTransactions.where((tx) => tx.subscriptionId == sub.id).toList();
      txsForSub.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final totalSpent =
          txsForSub.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final averageAmount =
          txsForSub.isNotEmpty ? totalSpent / txsForSub.length : sub.amount;
      final lastPaymentDate =
          txsForSub.isNotEmpty ? txsForSub.first.timestamp : sub.nextDueDate;

      return _SubscriptionSummary(
        subscription: sub,
        totalSpent: totalSpent,
        transactionCount: txsForSub.length,
        lastPaymentDate: lastPaymentDate,
        transactions: txsForSub, // All transactions for this sub
        averageAmount: averageAmount,
      );
    }).toList();

    summaries
        .sort((a, b) => a.subscription.name.compareTo(b.subscription.name));
    return summaries;
  }

  List<_SubscriptionPieSummary> _calculatePieSummaries(
      List<TransactionModel> periodTransactions,
      List<Subscription> allSubscriptions) {
    final Map<String, double> spentBySubId = {};
    for (var tx in periodTransactions) {
      if (tx.subscriptionId != null) {
        spentBySubId.update(tx.subscriptionId!, (value) => value + tx.amount,
            ifAbsent: () => tx.amount);
      }
    }

    final summaries = spentBySubId.entries.map((entry) {
      final sub = allSubscriptions.firstWhere((s) => s.id == entry.key,
          orElse: () => Subscription(
              id: 'unknown',
              name: 'Unlinked',
              amount: 0,
              category: '',
              paymentMethod: '',
              frequency: SubscriptionFrequency.monthly,
              nextDueDate: DateTime.now()));
      return _SubscriptionPieSummary(name: sub.name, totalAmount: entry.value);
    }).toList();

    summaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);

    // Data for the list view (all-time summary)
    final listSummaries =
        _processSubscriptions(subProvider.subscriptions, txProvider.transactions);

    // Data for the pie chart (period-specific)
    final range = _getFilterRange();
    final periodTransactions = txProvider.transactions.where((tx) {
      return tx.timestamp
              .isAfter(range.start.subtract(const Duration(microseconds: 1))) &&
          tx.timestamp.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();

    final pieSummaries =
        _calculatePieSummaries(periodTransactions, subProvider.subscriptions);
    final totalSpentInPeriod =
        pieSummaries.fold<double>(0.0, (sum, s) => sum + s.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DateFilterHeader(
                    label: _getFilterLabel(),
                    onTap: _showDateFilterModal,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PieChartSection(
                    summaries: pieSummaries,
                    totalAmount: totalSpentInPeriod,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'All Subscriptions (${listSummaries.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (listSummaries.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No subscriptions found.\nTap the + button to add a new one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    sliver: SliverList.builder(
                      itemCount: listSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = listSummaries[index];
                        return _SubscriptionCard(summary: summary);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final _SubscriptionSummary summary;
  const _SubscriptionCard({required this.summary});

  void _showPauseOptions(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: const Text('Pause next payment'),
              subtitle: const Text('The subscription will resume automatically after.'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  summary.subscription.copyWith(pauseState: SubscriptionPauseState.pausedUntilNext),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_filled_rounded),
              title: const Text('Pause indefinitely'),
              subtitle: const Text('Pause until you manually resume it.'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  summary.subscription.copyWith(pauseState: SubscriptionPauseState.pausedIndefinitely),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _archiveSubscription(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Subscription?'),
        content: const Text(
            'This will hide the subscription from this list. Existing transactions will not be affected. You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              provider.archiveSubscription(summary.subscription.id);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _resumeSubscription(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    provider.updateSubscription(summary.subscription.copyWith(pauseState: SubscriptionPauseState.active));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubscriptionDetailsScreen(
                subscription: summary.subscription,
                transactions: summary.transactions,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.sync_alt_rounded, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.subscription.name, style: theme.textTheme.titleLarge),
                      if (summary.subscription.pauseState != SubscriptionPauseState.active)
                        const _PausedChip(),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    currencyFormat.format(summary.averageAmount),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'pause') {
                        _showPauseOptions(context);
                      } else if (value == 'archive') {
                        _archiveSubscription(context);
                      } else if (value == 'resume') {
                        _resumeSubscription(context);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      if (summary.subscription.pauseState == SubscriptionPauseState.active)
                        const PopupMenuItem<String>(
                          value: 'pause',
                          child: ListTile(
                              leading: Icon(Icons.pause_rounded),
                              title: Text('Pause')),
                        )
                      else
                        const PopupMenuItem<String>(
                          value: 'resume',
                          child: ListTile(
                              leading: Icon(Icons.play_arrow_rounded),
                              title: Text('Resume')),
                        ),
                      const PopupMenuItem<String>(
                        value: 'archive',
                        child: ListTile(
                            leading: Icon(Icons.delete_forever_rounded),
                            title: Text('Archive')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(icon: Icons.repeat_rounded, label: summary.subscription.frequency.name),
                  _InfoChip(icon: Icons.event_available_rounded, label: 'Last: ${DateFormat.yMMMd().format(summary.lastPaymentDate)}'),
                  _InfoChip(icon: Icons.functions_rounded, label: '${summary.transactionCount} payments'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

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
  final List<_SubscriptionPieSummary> summaries;
  final double totalAmount;

  const _PieChartSection({required this.summaries, required this.totalAmount});

  Color _getColorForSubscription(String name) {
    final hash = name.hashCode;
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
                              color: _getColorForSubscription(summary.name),
                              title: '',
                              radius: 50,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      )
                    : Center(
                        child: Text(
                        "No subscription payments in this period.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      )),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: hasData
                    ? ListView.builder(
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
                                    color:
                                        _getColorForSubscription(summary.name),
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
      // For subscriptions, we only care about expenses.
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
                        'Select a month or deselect it to view stats for the whole year.',
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

class _PausedChip extends StatelessWidget {
  const _PausedChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('PAUSED',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}