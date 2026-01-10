import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/screens/all_subscriptions_screen.dart';
import 'package:wallzy/features/subscription/screens/subscription_details_screen.dart';

import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';

import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

// --- DATA MODELS (UNCHANGED) ---

class _SubscriptionPieSummary {
  final String subscriptionId;
  final String name;
  final double totalAmount;
  _SubscriptionPieSummary({
    required this.subscriptionId,
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
  // --- LOGIC SECTION (UNCHANGED) ---
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

  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final allTxs = txProvider.transactions;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
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
      return _SubscriptionPieSummary(
        subscriptionId: sub.id,
        name: sub.name,
        totalAmount: entry.value,
      );
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

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Payments')),
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildGlassFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: subProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildManagePaymentsTile(context, theme),
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 24.0),
                //   child: Divider(
                //     height: 1,
                //     color: theme.colorScheme.surfaceContainerHighest,
                //   ),
                // ),
                Expanded(
                  child: CustomScrollView(
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
                                _runFilter();
                              },
                            ),
                          ),
                        ),
                      ),

                      if (pieSummaries.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyReportPlaceholder(
                            message:
                                "You haven't made any recurring payments for this period",
                            icon: HugeIcons.strokeRoundedCalendar03,
                          ),
                        ),

                      if (pieSummaries.isNotEmpty) ...[
                        // 2. Dashboard Chart
                        SliverToBoxAdapter(
                          child: _SubscriptionDashboardPod(
                            summaries: pieSummaries,
                            totalAmount: totalSpentInPeriod,
                          ),
                        ),
                        // 3. Breakdown Title
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                            child: Text(
                              "Breakdown",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        // 4. List of items in that period
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final summary = pieSummaries[index];
                              final sub = subProvider.subscriptions.firstWhere(
                                (s) => s.id == summary.subscriptionId,
                                orElse: () => Subscription(
                                  id: summary.subscriptionId,
                                  name: summary.name,
                                  amount: 0,
                                  category: '',
                                  paymentMethod: '',
                                  frequency: SubscriptionFrequency.monthly,
                                  nextDueDate: DateTime.now(),
                                ),
                              );

                              final subTransactions = txProvider.transactions
                                  .where(
                                    (tx) =>
                                        tx.subscriptionId ==
                                        summary.subscriptionId,
                                  )
                                  .toList();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SubscriptionDetailsScreen(
                                              subscription: sub,
                                              transactions: subTransactions,
                                            ),
                                      ),
                                    );
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      summary.name.isNotEmpty
                                          ? summary.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    summary.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: Text(
                                    NumberFormat.compactCurrency(
                                      symbol: currencySymbol,
                                      decimalDigits: 0,
                                    ).format(summary.totalAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: pieSummaries.length),
                          ),
                        ),
                      ],

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildManagePaymentsTile(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllRecurringPaymentsScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IgnorePointer(
                child: IconButton.filledTonal(
                  onPressed: () {},
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRotate02,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Manage Payments",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "View active & inactive plans",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Recurring Payment",
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
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
