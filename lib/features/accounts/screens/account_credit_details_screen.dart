import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/widgets/account_info_modal_sheet.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalIncome; // Mapped to Repayments
  final double totalExpense; // Mapped to Purchases

  _MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class AccountIncomeDetailsScreen extends StatefulWidget {
  final Account account;

  const AccountIncomeDetailsScreen({super.key, required this.account});

  @override
  State<AccountIncomeDetailsScreen> createState() =>
      _AccountIncomeDetailsScreenState();
}

class _AccountIncomeDetailsScreenState
    extends State<AccountIncomeDetailsScreen> {
  List<TransactionModel> _accountTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxAmount = 0;
  double _maxIncome = 0; // Max Repayment
  double _maxExpense = 0; // Max Purchase
  double _meanIncome = 0; // Mean Repayment
  double _meanExpense = 0; // Mean Purchase
  double _totalCreditDue = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndProcessTransactions();
    });
  }

  void _loadAndProcessTransactions() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    _accountTransactions = allTransactions
        .where((tx) => tx.accountId == widget.account.id)
        .toList();

    if (_accountTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
      });
    }
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _accountTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _accountTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    // Calculate total due for the entire account history
    double totalDue = 0;
    for (final tx in _accountTransactions) {
      if (tx.category == 'Credit Repayment') {
        // Repayments (from any type) decrease the due amount.
        totalDue -= tx.amount;
      } else if (tx.type == 'expense') {
        // Regular purchases increase the due amount.
        totalDue += tx.amount;
      } else if (tx.type == 'income') {
        // This handles refunds
        totalDue -= tx.amount;
      }
    }

    final summaries = groupedByMonth.entries.map((entry) {
      double purchases = 0;
      double repayments = 0;
      for (var tx in entry.value) {
        if (tx.category == 'Credit Repayment') {
          repayments += tx.amount;
        } else if (tx.type == 'expense') {
          purchases += tx.amount;
        } else if (tx.type == 'income') {
          // Refunds
          repayments += tx.amount;
        }
      }
      return _MonthlySummary(
        month: entry.key,
        totalIncome: repayments, // Mapped to 'income' for chart reuse
        totalExpense: purchases, // Mapped to 'expense' for chart reuse
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b); // Max Repayment
      _maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b); // Max Purchase
      _maxAmount = _maxIncome > _maxExpense ? _maxIncome : _maxExpense;

      final totalRepaymentSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalIncome,
      );
      _meanIncome = totalRepaymentSum / summaries.length; // Mean Repayment

      final totalPurchaseSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalExpense,
      );
      _meanExpense = totalPurchaseSum / summaries.length; // Mean Purchase
    }

    setState(() {
      _totalCreditDue = totalDue;
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        _selectMonth(_monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  Widget _buildCreditLimitBlock() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final limit = widget.account.creditLimit ?? 0.0;

    // Safety check
    if (limit <= 0) return const SizedBox.shrink();

    final used = _totalCreditDue;
    final available = limit - used;
    // Clamp utilization between 0.0 and 1.0 for visual safety
    final utilization = (used / limit).clamp(0.0, 1.0);

    // Logic: High utilization (> 75%) is "Bad" (Error color), otherwise "Good" (Primary color)
    final isHighUtilization = utilization > 0.75;
    final healthColor = isHighUtilization
        ? colorScheme.error
        : colorScheme.primary;
    // The "Empty" space color needs to be visible on the dark 'inverseSurface' background
    final emptyColor = colorScheme.onSurface.withAlpha(38);

    // Calculate Flex values for the bar segments
    final int usedFlex = (utilization * 100).toInt();
    final int availableFlex = ((1 - utilization) * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CREDIT HEALTH",
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(178),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHighUtilization
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: healthColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHighUtilization ? "High Usage" : "Good",
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero: Available Credit
          Text(
            currencyFormat.format(available),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Available Limit",
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(130),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 12),

          // Visual Ratio Bar (Split Rounded Containers)
          SizedBox(
            height: 12,
            child: Row(
              children: [
                // Used Portion
                if (usedFlex > 0)
                  Expanded(
                    flex: usedFlex,
                    child: Container(
                      decoration: BoxDecoration(
                        color: healthColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                // Gap (only if both parts exist)
                if (usedFlex > 0 && availableFlex > 0) const SizedBox(width: 6),

                // Available Portion
                if (availableFlex > 0)
                  Expanded(
                    flex: availableFlex,
                    child: Container(
                      decoration: BoxDecoration(
                        color: emptyColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Footer Stats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "USED",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(used),
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 24,
                width: 1,
                color: colorScheme.onSurface.withAlpha(50),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL LIMIT",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(limit),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountInfoModalSheet(
        account: widget.account,
        passedContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep your currencyFormat definition
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.account.bankName),
            const SizedBox(height: 4),
            Text(
              widget.account.accountNumber,
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
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showAccountInfo,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Credit Utilization Block (New, like Net Worth)
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 16),
                child: _buildCreditLimitBlock(),
              ),
            ),

          // 2. Graph
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),

          // 3. Monthly Summary Card (Redesigned)
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard()),

          // 4. Transaction List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                // Dynamic header based on selection
                _selectedMonth != null
                    ? '${_displayTransactions.length} Transactions in ${DateFormat('MMM').format(_selectedMonth!)}'
                    : 'Transactions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 5. Grouped Transactions
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No transactions found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            _buildTransactionList(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    const double barWidth = 50.0;
    const double barSpacing = 24.0;
    final double chartWidth =
        _monthlySummaries.length * (barWidth + barSpacing) + 40;
    final appColors = Theme.of(context).extension<AppColors>()!;

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
                    'Max\n${currencyFormat.format(_maxAmount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mean (Paid)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.income,
                        ),
                      ),
                      Text(
                        currencyFormat.format(_meanIncome),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mean (Used)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.expense,
                        ),
                      ),
                      Text(
                        currencyFormat.format(_meanExpense),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
                height: 280,
                child: Stack(
                  children: [
                    BarChart(_buildBarChartData(currencyFormat)),
                    LineChart(_buildLineChartData(currencyFormat)),
                  ],
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

  BarChartData _buildBarChartData(NumberFormat currencyFormat) {
    return BarChartData(
      maxY: _maxAmount == 0 ? 1 : _maxAmount * 1.2,
      barTouchData: _buildBarTouchData(),
      titlesData: _buildTitlesData(currencyFormat),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      barGroups: _buildBarGroups(context),
      alignment: BarChartAlignment.spaceAround,
    );
  }

  LineChartData _buildLineChartData(NumberFormat currencyFormat) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return LineChartData(
      minY: 0,
      maxY: _maxAmount == 0 ? 1 : _maxAmount * 1.2,
      minX: 0,
      maxX: _monthlySummaries.length.toDouble(),
      gridData: const FlGridData(show: false),
      titlesData: _buildTitlesData(currencyFormat, showLabels: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(_monthlySummaries.length, (index) {
            final summary = _monthlySummaries[index];
            return FlSpot(index.toDouble() + 0.5, summary.totalIncome);
          }),
          isCurved: true,
          color: appColors.income,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }

  FlTitlesData _buildTitlesData(
    NumberFormat currencyFormat, {
    bool showLabels = true,
  }) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            if (!showLabels) return const SizedBox.shrink();
            final index = value.toInt();
            if (index < 0 || index >= _monthlySummaries.length) {
              return const SizedBox();
            }

            final summary = _monthlySummaries[index];
            final isSelected = summary.month == _selectedMonth;

            return SideTitleWidget(
              meta: meta,
              space: 12.0,
              child: GestureDetector(
                onTap: () => _selectMonth(summary.month),
                child: AnimatedContainer(
                  width: 70,
                  padding: const EdgeInsets.all(6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  duration: const Duration(milliseconds: 200),
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
                        currencyFormat.format(
                          summary.totalIncome,
                        ), // Repayments
                        style: TextStyle(color: appColors.income, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(
                          summary.totalExpense,
                        ), // Purchases
                        style: TextStyle(
                          color: appColors.expense,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          reservedSize: 77,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return List.generate(_monthlySummaries.length, (index) {
      final summary = _monthlySummaries[index];
      final isSelected = summary.month == _selectedMonth;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: summary.totalExpense, // Purchases
            color: isSelected
                ? appColors.expense
                : appColors.expense.withAlpha(80),
            width: 25,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  // --- REDESIGNED MONTHLY SUMMARY (Split Container Style) ---
  Widget _buildSummaryCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final appColors = Theme.of(context).extension<AppColors>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selectedSummary = _monthlySummaries.firstWhereOrNull(
      (summary) => summary.month == _selectedMonth,
    );

    if (selectedSummary == null) return const SizedBox.shrink();

    // Map logic: Income = Payments, Expense = Spends
    final payments = selectedSummary.totalIncome;
    final spends = selectedSummary.totalExpense;
    // Net Change: Positive means we paid off more than we spent (Good)
    final netChange = payments - spends;
    final totalVolume = payments + spends;

    // Flex ratios
    final int payFlex = totalVolume == 0
        ? 0
        : ((payments / totalVolume) * 100).toInt();
    final int spendFlex = totalVolume == 0
        ? 0
        : ((spends / totalVolume) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MONTHLY ACTIVITY",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM yyyy').format(_selectedMonth!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hero Number
            Text(
              "Net Repayment",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currencyFormat.format(netChange),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: netChange >= 0 ? appColors.income : appColors.expense,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            // Visual Ratio Bar (Split Containers)
            if (totalVolume > 0)
              SizedBox(
                height: 12,
                child: Row(
                  children: [
                    // Payment Bar (Green)
                    if (payFlex > 0)
                      Expanded(
                        flex: payFlex,
                        child: Container(
                          decoration: BoxDecoration(
                            color: appColors.income,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    // Gap
                    if (payFlex > 0 && spendFlex > 0) const SizedBox(width: 6),
                    // Spend Bar (Red)
                    if (spendFlex > 0)
                      Expanded(
                        flex: spendFlex,
                        child: Container(
                          decoration: BoxDecoration(
                            color: appColors.expense,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            if (totalVolume > 0) const SizedBox(height: 20),

            // Stats Columns
            Row(
              children: [
                // Payments
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.income,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "PAYMENTS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(payments),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 30,
                  width: 1,
                  color: colors.outlineVariant.withOpacity(0.5),
                ),
                const SizedBox(width: 24),
                // Spends
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.expense,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "SPENDS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(spends),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return GroupedTransactionList(
      transactions: _displayTransactions,
      onTap: (tx) => _showTransactionDetails(context, tx),
      useSliver: true,
    );
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
}
