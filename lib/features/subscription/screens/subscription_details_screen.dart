import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/subscription/widgets/subscription_info_modal_sheet.dart';

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
    return provider.allSubscriptions.firstWhere(
      (s) => s.id == widget.subscription.id,
      orElse: () => widget.subscription,
    );
  }

  void _restoreSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: 'Restore Subscription?',
        description:
            'This will move the subscription back to your active list and re-enable payment reminders.',
        icon: HugeIcons.strokeRoundedRotate01,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              "Restore",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              provider.restoreSubscription(widget.subscription.id);
              Navigator.pop(ctx);
            },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SubscriptionInfoModalSheet(subscription: _getCurrentSubscription()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final theme = Theme.of(context);

    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, child) {
        final currentSubscription = subProvider.subscriptions.firstWhere(
          (s) => s.id == widget.subscription.id,
          orElse: () => widget.subscription,
        );
        final isPaused =
            currentSubscription.pauseState != SubscriptionPauseState.active;
        final isArchived = !currentSubscription.isActive;

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
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  strokeWidth: 2,
                  size: 20,
                ),
                onPressed: _showSubscriptionInfoModal,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              if (_monthlySummaries.isNotEmpty)
                SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
              if (_displayTransactions.isNotEmpty)
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
                  child: EmptyReportPlaceholder(
                    message: 'Payments for this recurring will appear here.',
                    icon: HugeIcons.strokeRoundedRotate02,
                  ),
                )
              else
                _buildTransactionList(),
            ],
          ),
          bottomNavigationBar: (isPaused || isArchived)
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    icon: Icon(
                      isArchived
                          ? Icons.settings_backup_restore_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      isArchived
                          ? 'Restore Subscription'
                          : 'Resume Subscription',
                    ),
                    onPressed: isArchived
                        ? _restoreSubscription
                        : _resumeSubscription,
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
              meta: meta,
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
                : Theme.of(context).colorScheme.primary.withAlpha(80),
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
