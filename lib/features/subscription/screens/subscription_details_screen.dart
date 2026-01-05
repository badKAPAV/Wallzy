import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
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
      _maxSpent = summaries
          .map((s) => s.totalAmount)
          .reduce((a, b) => a > b ? a : b);
      final totalSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalAmount,
      );
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

  Subscription _getCurrentSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    return provider.subscriptions.firstWhere(
      (s) => s.id == widget.subscription.id,
      orElse: () => widget.subscription,
    );
  }

  void _editSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddSubscriptionScreen(subscription: _getCurrentSubscription()),
      ),
    );
  }

  void _showPauseOptions() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final currentObj = _getCurrentSubscription();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: const Text('Pause next payment'),
              subtitle: const Text(
                'The subscription will resume automatically after.',
              ),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSubscription(
                  currentObj.copyWith(
                    pauseState: SubscriptionPauseState.pausedUntilNext,
                  ),
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
                  currentObj.copyWith(
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

  void _archiveSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Subscription?'),
        content: const Text(
          'This will hide the subscription from this list. Existing transactions will not be affected. You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
    final currentObj = _getCurrentSubscription();
    provider.updateSubscription(
      currentObj.copyWith(pauseState: SubscriptionPauseState.active),
    );
  }

  void _showSubscriptionInfoModal() {
    final theme = Theme.of(context);
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final currentObj = _getCurrentSubscription();
    String methodDisplay = currentObj.paymentMethod;

    if (currentObj.accountId != null) {
      final account = accountProvider.accounts.firstWhereOrNull(
        (a) => a.id == currentObj.accountId,
      );
      if (account != null) {
        methodDisplay = '$methodDisplay (${account.bankName})';
      }
    }

    final isPaused = currentObj.pauseState != SubscriptionPauseState.active;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  currentObj.name.isNotEmpty
                      ? currentObj.name[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                currentObj.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(currentObj.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Details Grid
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      theme,
                      'Next Due',
                      DateFormat('MMM d').format(currentObj.nextDueDate),
                      Icons.calendar_today_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoItem(
                      theme,
                      'Frequency',
                      currentObj.frequency.name.toUpperCase(),
                      Icons.repeat_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      theme,
                      'Category',
                      currentObj.category,
                      Icons.category_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoItem(
                      theme,
                      'Method',
                      methodDisplay,
                      Icons.payment_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editSubscription();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (isPaused) {
                          _resumeSubscription();
                        } else {
                          _showPauseOptions();
                        }
                      },
                      icon: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(isPaused ? 'Resume' : 'Pause'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _archiveSubscription();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive Subscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
                Text(
                  currentSubscription.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Recurring Payment',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: _showSubscriptionInfoModal,
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              if (_monthlySummaries.isNotEmpty)
                SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
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
                          avatar: Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          ),
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
                    child: Text('No payments found for this subscription.'),
                  ),
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
    final double chartWidth =
        _monthlySummaries.length * (barWidth + barSpacing);

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
                  Text(
                    'Max\n${currencyFormat.format(_maxSpent)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Mean\n${currencyFormat.format(_meanSpent)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
            if (index < 0 || index >= _monthlySummaries.length) {
              return const SizedBox();
            }

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
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(summary.totalAmount),
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
    return GroupedTransactionList(
      transactions: _displayTransactions,
      onTap: (tx) => _showTransactionDetails(context, tx),
      useSliver: true,
    );
  }
}
