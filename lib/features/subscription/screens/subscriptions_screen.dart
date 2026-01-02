import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/screens/subscription_details_screen.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';

// --- DATA MODELS (UNCHANGED) ---
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

class _SubscriptionPieSummary {
  final String name;
  final double totalAmount;
  _SubscriptionPieSummary({required this.name, required this.totalAmount});
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  // --- LOGIC SECTION (UNCHANGED) ---
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  List<int> _availableYears = [];
  bool _isLoading = true;

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
    setState(() => _isLoading = false);
  }

  void _runFilter() {
    setState(() {});
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

  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final allTxs = txProvider.transactions;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );

    Map<int, String> stats = {};
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      final monthTotal = allTxs
          .where(
            (tx) =>
                tx.subscriptionId != null &&
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

  List<_SubscriptionSummary> _processSubscriptions(
    List<Subscription> subscriptions,
    List<TransactionModel> allTransactions,
  ) {
    final summaries = subscriptions.map((sub) {
      final txsForSub = allTransactions
          .where((tx) => tx.subscriptionId == sub.id)
          .toList();
      txsForSub.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final totalSpent = txsForSub.fold<double>(
        0.0,
        (sum, tx) => sum + tx.amount,
      );
      final averageAmount = txsForSub.isNotEmpty
          ? totalSpent / txsForSub.length
          : sub.amount;
      final lastPaymentDate = txsForSub.isNotEmpty
          ? txsForSub.first.timestamp
          : sub.nextDueDate;

      return _SubscriptionSummary(
        subscription: sub,
        totalSpent: totalSpent,
        transactionCount: txsForSub.length,
        lastPaymentDate: lastPaymentDate,
        transactions: txsForSub,
        averageAmount: averageAmount,
      );
    }).toList();
    summaries.sort(
      (a, b) => a.subscription.name.compareTo(b.subscription.name),
    );
    return summaries;
  }

  List<_SubscriptionPieSummary> _calculatePieSummaries(
    List<TransactionModel> periodTransactions,
    List<Subscription> allSubscriptions,
  ) {
    final Map<String, double> spentBySubId = {};
    for (var tx in periodTransactions) {
      if (tx.subscriptionId != null) {
        spentBySubId.update(
          tx.subscriptionId!,
          (value) => value + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final summaries = spentBySubId.entries.map((entry) {
      final sub = allSubscriptions.firstWhere(
        (s) => s.id == entry.key,
        orElse: () => Subscription(
          id: 'unknown',
          name: 'Unlinked',
          amount: 0,
          category: '',
          paymentMethod: '',
          frequency: SubscriptionFrequency.monthly,
          nextDueDate: DateTime.now(),
        ),
      );
      return _SubscriptionPieSummary(name: sub.name, totalAmount: entry.value);
    }).toList();
    summaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return summaries;
  }

  // --- REDESIGNED BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);

    // Logic Execution
    final listSummaries = _processSubscriptions(
      subProvider.subscriptions,
      txProvider.transactions,
    );
    final range = _getFilterRange();
    final periodTransactions = txProvider.transactions.where((tx) {
      return tx.timestamp.isAfter(
            range.start.subtract(const Duration(microseconds: 1)),
          ) &&
          tx.timestamp.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();
    final pieSummaries = _calculatePieSummaries(
      periodTransactions,
      subProvider.subscriptions,
    );
    final totalSpentInPeriod = pieSummaries.fold<double>(
      0.0,
      (sum, s) => sum + s.totalAmount,
    );

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text("Subscriptions"),
                  centerTitle: false,
                  backgroundColor: theme.scaffoldBackgroundColor.withOpacity(
                    0.9,
                  ),
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  actions: [
                    IconButton.filledTonal(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddSubscriptionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),

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

                // 2. Dashboard Chart
                SliverToBoxAdapter(
                  child: _SubscriptionDashboardPod(
                    summaries: pieSummaries,
                    totalAmount: totalSpentInPeriod,
                  ),
                ),

                // 3. List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      'ACTIVE PLANS (${listSummaries.length})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),

                // 4. Subscription List
                if (listSummaries.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No subscriptions found.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final summary = listSummaries[index];
                      return _FunkySubscriptionTile(summary: summary);
                    }, childCount: listSummaries.length),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }
}

// --- REDESIGNED WIDGETS ---

// [Deleted local classes]

class _SubscriptionDashboardPod extends StatelessWidget {
  final List<_SubscriptionPieSummary> summaries;
  final double totalAmount;

  const _SubscriptionDashboardPod({
    required this.summaries,
    required this.totalAmount,
  });

  Color _getColorForSubscription(String name) {
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
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );
    final hasData = summaries.isNotEmpty && totalAmount > 0;
    final theme = Theme.of(context);

    // Show top 4 in legend
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
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: summaries.map((summary) {
                            final percentage =
                                (summary.totalAmount / totalAmount) * 100;
                            return PieChartSectionData(
                              value: percentage,
                              color: _getColorForSubscription(summary.name),
                              radius: 20,
                              showTitle: false,
                            );
                          }).toList(),
                          sectionsSpace: 4,
                          centerSpaceRadius: 70,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Total Spent",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          Text(
                            currencyFormat.format(totalAmount),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        color: _getColorForSubscription(s.name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

class _FunkySubscriptionTile extends StatelessWidget {
  final _SubscriptionSummary summary;
  const _FunkySubscriptionTile({required this.summary});

  // --- Actions Logic (Unchanged) ---
  void _showPauseOptions(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('Pause next payment'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  summary.subscription.copyWith(
                    pauseState: SubscriptionPauseState.pausedUntilNext,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_filled),
              title: const Text('Pause indefinitely'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  summary.subscription.copyWith(
                    pauseState: SubscriptionPauseState.pausedIndefinitely,
                  ),
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
        title: const Text('Archive?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
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
    Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    ).updateSubscription(
      summary.subscription.copyWith(pauseState: SubscriptionPauseState.active),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isPaused =
        summary.subscription.pauseState != SubscriptionPauseState.active;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.sync_alt_rounded,
                      color: isPaused
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.subscription.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: isPaused
                                ? TextDecoration.lineThrough
                                : null,
                            color: isPaused
                                ? theme.colorScheme.outline
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isPaused)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "PAUSED",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(summary.averageAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "/${summary.subscription.frequency.name}",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.outline,
                    ),
                    onSelected: (val) {
                      if (val == 'pause') _showPauseOptions(context);
                      if (val == 'resume') _resumeSubscription(context);
                      if (val == 'archive') _archiveSubscription(context);
                    },
                    itemBuilder: (ctx) => [
                      if (!isPaused)
                        const PopupMenuItem(
                          value: 'pause',
                          child: Text('Pause'),
                        ),
                      if (isPaused)
                        const PopupMenuItem(
                          value: 'resume',
                          child: Text('Resume'),
                        ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Footer Chips
              Row(
                children: [
                  _DetailPill(
                    icon: Icons.calendar_today_rounded,
                    label:
                        "Last: ${DateFormat('MMM d').format(summary.lastPaymentDate)}",
                  ),
                  const SizedBox(width: 8),
                  _DetailPill(
                    icon: Icons.receipt_long_rounded,
                    label: "${summary.transactionCount} paid",
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

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
