import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalAmount;

  _MonthlySummary({required this.month, required this.totalAmount});
}

class SubscriptionDetailsScreen extends StatefulWidget {
  final Subscription subscription;
  final List<TransactionModel> transactions;

  const SubscriptionDetailsScreen({
    super.key,
    required this.subscription,
    required this.transactions,
  });

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxSpent = 0;
  double _meanSpent = 0;

  @override
  void initState() {
    super.initState();
    _processTransactions();
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = widget.transactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
      List<TransactionModel> transactions) {
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

  void _processTransactions() {
    final groupedByMonth = groupBy(
      widget.transactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    final summaries = groupedByMonth.entries.map((entry) {
      final total = entry.value.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return _MonthlySummary(month: entry.key, totalAmount: total);
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxSpent =
          summaries.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);
      final totalSum =
          summaries.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
      _meanSpent = totalSum / summaries.length;
    }

    setState(() {
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        _selectMonth(_monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  void _editSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(subscription: widget.subscription),
      ),
    );
  }

  void _showPauseOptions() {
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
              subtitle:
                  const Text('The subscription will resume automatically after.'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  widget.subscription
                      .copyWith(pauseState: SubscriptionPauseState.pausedUntilNext),
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
                  widget.subscription.copyWith(
                      pauseState: SubscriptionPauseState.pausedIndefinitely),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _archiveSubscription() {
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
              provider.archiveSubscription(widget.subscription.id);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _resumeSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    provider.updateSubscription(
      widget.subscription.copyWith(pauseState: SubscriptionPauseState.active),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final theme = Theme.of(context);

    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, child) {
        final currentSubscription = subProvider.subscriptions.firstWhere(
          (s) => s.id == widget.subscription.id,
          orElse: () => widget.subscription,
        );
        final isPaused =
            currentSubscription.pauseState != SubscriptionPauseState.active;

        return Scaffold(
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentSubscription.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'Subscription',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editSubscription();
                  } else if (value == 'pause') {
                    _showPauseOptions();
                  } else if (value == 'archive') {
                    _archiveSubscription();
                  } else if (value == 'resume') {
                    _resumeSubscription();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                        leading: Icon(Icons.edit_rounded), title: Text('Edit')),
                  ),
                  if (!isPaused)
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
                        leading: Icon(Icons.archive_rounded),
                        title: Text('Archive')),
                  ),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              if (_monthlySummaries.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildGraphSection(currencyFormat),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _displayTransactions.length == 1
                            ? '1 Payment'
                            : '${_displayTransactions.length} Payments',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (isPaused)
                        ActionChip(
                          avatar: Icon(Icons.pause_circle_filled_rounded,
                              size: 18, color: theme.colorScheme.secondary),
                          label: const Text('Paused'),
                          onPressed: _resumeSubscription,
                        ),
                    ],
                  ),
                ),
              ),
              if (_displayTransactions.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                      child:
                          Text('No payments found for this subscription.')),
                )
              else
                _buildTransactionList(),
            ],
          ),
          bottomNavigationBar: isPaused
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume Subscription'),
                    onPressed: _resumeSubscription,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    const double barWidth = 50.0;
    const double barSpacing = 24.0;
    final double chartWidth = _monthlySummaries.length * (barWidth + barSpacing);

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
                  Text('Max\n${currencyFormat.format(_maxSpent)}', style: Theme.of(context).textTheme.bodySmall),
                  Text('Mean\n${currencyFormat.format(_meanSpent)}', style: Theme.of(context).textTheme.bodySmall),
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
                height: 250,
                child: BarChart(
                  BarChartData(
                    groupsSpace: 40,
                    maxY: _maxSpent == 0 ? 1 : _maxSpent * 1.1,
                    barTouchData: _buildBarTouchData(),
                    titlesData: _buildTitlesData(currencyFormat),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: _buildBarGroups(),
                    alignment: BarChartAlignment.center,
                  ),
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
        tooltipMargin: 4,
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

  FlTitlesData _buildTitlesData(NumberFormat currencyFormat) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            final index = value.toInt();
            if (index < 0 || index >= _monthlySummaries.length) return const SizedBox();

            final summary = _monthlySummaries[index];
            final isSelected = summary.month == _selectedMonth;

            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8.0,
              child: GestureDetector(
                onTap: () => _selectMonth(summary.month),
                child: Container(
                width: 60,
                padding: const EdgeInsets.all(6),
                decoration: isSelected
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM \'yy').format(summary.month),
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(summary.totalAmount),
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
          reservedSize: 60,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_monthlySummaries.length, (index) {
      final summary = _monthlySummaries[index];
      final isSelected = summary.month == _selectedMonth;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: summary.totalAmount,
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 25,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTransactionList() {
    final groupedTransactions = _groupTransactionsByDate(_displayTransactions);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
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
        },
        childCount: groupedTransactions.length,
      ),
    );
  }
}