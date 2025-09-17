import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisFiscalYear,
  lastFiscalYear,
  custom,
}

class ChartData {
  final List<FlSpot> incomeSpots;
  final List<FlSpot> expenseSpots;
  final List<FlSpot> balanceSpots;
  final double maxY;
  final double minY;
  final bool hasData;

  ChartData({
    required this.incomeSpots,
    required this.expenseSpots,
    required this.balanceSpots,
    required this.maxY,
    required this.minY,
    this.hasData = true,
  });
}

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late TransactionFilter _filter;
  FilterResult? _result;
  DateFilterType? _selectedFilterType;
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _filter = const TransactionFilter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    final years = allTransactions
        .map((tx) => tx.timestamp.year)
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    setState(() {
      _availableYears = years;
      final now = DateTime.now();
      _selectedYear = now.year;
      if (_availableYears.isNotEmpty &&
          !_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    });
    _updateDateFilter(year: _selectedYear);
  }

  void _runFilter() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    setState(() {
      _result = provider.getFilteredResults(_filter);
    });
  }

  void _updateFilter(TransactionFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _runFilter();
  }

  void _updateDateFilter({
    DateFilterType? type,
    int? year,
    int? month,
    DateTimeRange? customRange,
  }) {
    final now = DateTime.now();
    DateTimeRange range = _getYearRange(now.year);
    setState(() {
      _selectedFilterType = type;
      _selectedYear = year;
      _selectedMonth = month;
    });
    if (customRange != null) {
      range = customRange;
    } else if (_selectedFilterType != null) {
      range = _getRangeForType(_selectedFilterType!);
    } else if (_selectedYear != null) {
      if (_selectedMonth != null) {
        range = _getMonthRange(_selectedYear!, _selectedMonth!);
      } else {
        range = _getYearRange(_selectedYear!);
      }
    }
    _updateFilter(
      _filter.copyWith(
        startDate: () => range.start,
        endDate: () =>
            DateTime(range.end.year, range.end.month, range.end.day + 1),
      ),
    );
  }

  String _getDateFilterLabel() {
    if (_selectedFilterType != null) {
      switch (_selectedFilterType!) {
        case DateFilterType.today:
          return 'Today';
        case DateFilterType.yesterday:
          return 'Yesterday';
        case DateFilterType.thisWeek:
          return 'This Week';
        case DateFilterType.lastWeek:
          return 'Last Week';
        case DateFilterType.thisMonth:
          return 'This Month';
        case DateFilterType.lastMonth:
          return 'Last Month';
        case DateFilterType.thisQuarter:
          return 'This Quarter';
        case DateFilterType.lastQuarter:
          return 'Last Quarter';
        case DateFilterType.thisFiscalYear:
          return 'This Fiscal Year';
        case DateFilterType.lastFiscalYear:
          return 'Last Fiscal Year';
        case DateFilterType.custom:
          if (_filter.startDate != null && _filter.endDate != null) {
            final start = DateFormat.MMMd().format(_filter.startDate!);
            final end = DateFormat.yMMMd().format(
              _filter.endDate!.subtract(const Duration(days: 1)),
            );
            if (start == end) return start;
            return '$start - $end';
          }
          return 'Custom';
      }
    }
    if (_selectedYear != null) {
      if (_selectedMonth != null)
        return '${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}, $_selectedYear';
      return _selectedYear.toString();
    }
    return 'Select Date';
  }

  String _getFormattedDateRangeLabel() {
    if (_filter.startDate == null || _filter.endDate == null)
      return 'Showing results for All Time';
    final start = _filter.startDate!;
    final end = _filter.endDate!.subtract(const Duration(days: 1));
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return 'Showing results for ${DateFormat('EEEE, d MMMM, yyyy').format(start)}';
    }
    final startFormat = DateFormat('d MMM, yyyy');
    final endFormat = DateFormat('d MMM, yyyy');
    return 'Showing results for ${startFormat.format(start)} - ${endFormat.format(end)}';
  }

  void _showDateFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DateFilterModalContent(
        initialFilterType: _selectedFilterType,
        initialYear: _selectedYear,
        initialMonth: _selectedMonth,
        initialCustomRange:
            (_filter.startDate != null && _filter.endDate != null)
                ? DateTimeRange(
                    start: _filter.startDate!,
                    end: _filter.endDate!.subtract(const Duration(days: 1)),
                  )
                : null,
        availableYears: _availableYears,
        onApply: (type, year, month, customRange) {
          if (type == DateFilterType.custom) {
            _updateDateFilter(
              type: type,
              year: null,
              month: null,
              customRange: customRange,
            );
          } else {
            _updateDateFilter(type: type, year: year, month: month);
          }
        },
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterModalContent(
        initialFilter: _filter,
        onApply: (newFilter) {
          _updateFilter(newFilter);
        },
      ),
    );
  }

  ChartData _processChartData(List<TransactionModel> transactions, int year) {
    List<double> monthlyIncome = List.filled(12, 0.0);
    List<double> monthlyExpense = List.filled(12, 0.0);
    List<double> monthlyBalance = List.filled(12, 0.0);
    double maxAmount = 0.0, minAmount = 0.0;

    List<TransactionModel> yearTransactions =
        transactions.where((tx) => tx.timestamp.year == year).toList();

    if (yearTransactions.isEmpty) {
      return ChartData(
        incomeSpots: [],
        expenseSpots: [],
        balanceSpots: [],
        maxY: 0,
        minY: 0,
        hasData: false,
      );
    }

    final singleCategory = _filter.categories?.isNotEmpty == true
        ? _filter.categories!.first
        : null;
    final singlePaymentMethod = _filter.paymentMethods?.isNotEmpty == true
        ? _filter.paymentMethods!.first
        : null;
    final singleTag =
        _filter.tags?.isNotEmpty == true ? _filter.tags!.first : null;
    final singlePerson =
        _filter.people?.isNotEmpty == true ? _filter.people!.first : null;

    yearTransactions = yearTransactions.where((tx) {
      if (singleCategory != null && tx.category != singleCategory) return false;
      if (singlePaymentMethod != null &&
          tx.paymentMethod != singlePaymentMethod) return false;
      if (singleTag != null &&
          !(tx.tags?.any((t) => t.id == singleTag.id) ?? false)) return false;
      if (singlePerson != null &&
          !(tx.people?.any((p) => p.id == singlePerson.id) ?? false))
        return false;
      return true;
    }).toList();

    if (yearTransactions.isEmpty) {
      return ChartData(
        incomeSpots: [],
        expenseSpots: [],
        balanceSpots: [],
        maxY: 0,
        minY: 0,
        hasData: false,
      );
    }

    for (final tx in yearTransactions) {
      final monthIndex = tx.timestamp.month - 1;
      if (tx.type == 'income')
        monthlyIncome[monthIndex] += tx.amount;
      else
        monthlyExpense[monthIndex] += tx.amount;
    }

    for (int i = 0; i < 12; i++) {
      monthlyBalance[i] = monthlyIncome[i] - monthlyExpense[i];
      if (monthlyIncome[i] > maxAmount) maxAmount = monthlyIncome[i];
      if (monthlyExpense[i] > maxAmount) maxAmount = monthlyExpense[i];
      if (monthlyBalance[i] > maxAmount) maxAmount = monthlyBalance[i];
      if (monthlyBalance[i] < minAmount) minAmount = monthlyBalance[i];
    }

    List<FlSpot> _addBulgeAnchors(List<double> monthlyData) {
      final activeMonths = <int>[];
      for (int i = 0; i < 12; i++) {
        if (monthlyData[i] != 0) activeMonths.add(i);
      }
      if (activeMonths.length == 1) {
        final monthIndex = activeMonths.first;
        final x = monthIndex.toDouble();
        final prevX = (x - 1 < 0) ? x - 0.1 : x - 1;
        final nextX = (x + 1 > 11) ? x + 0.1 : x + 1;
        return [
          FlSpot(prevX, 0),
          FlSpot(x, monthlyData[monthIndex]),
          FlSpot(nextX, 0),
        ];
      } else {
        List<FlSpot> spots = [];
        for (int i = 0; i < 12; i++) {
          if (monthlyData[i] != 0)
            spots.add(FlSpot(i.toDouble(), monthlyData[i]));
          else
            spots.add(FlSpot.nullSpot);
        }
        return spots;
      }
    }

    maxAmount = maxAmount == 0.0 ? 1000 : maxAmount * 1.2;
    minAmount = minAmount < 0 ? minAmount * 1.2 : -(maxAmount * 0.1);

    return ChartData(
      incomeSpots: _addBulgeAnchors(monthlyIncome),
      expenseSpots: _addBulgeAnchors(monthlyExpense),
      balanceSpots: _addBulgeAnchors(monthlyBalance),
      maxY: maxAmount,
      minY: minAmount,
      hasData: true,
    );
  }

  Widget _buildActiveFilters() {
    final activeFilters = [];
    if (_filter.type != null) {
      activeFilters.add({'type': 'type', 'value': _filter.type});
    }
    _filter.categories?.forEach(
      (c) => activeFilters.add({'type': 'category', 'value': c}),
    );
    _filter.paymentMethods?.forEach(
      (p) => activeFilters.add({'type': 'paymentMethod', 'value': p}),
    );
    _filter.tags?.forEach(
      (t) => activeFilters.add({'type': 'tag', 'value': t}),
    );
    _filter.people?.forEach(
      (p) => activeFilters.add({'type': 'person', 'value': p}),
    );
    if (activeFilters.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 36,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        itemCount: activeFilters.length,
        itemBuilder: (context, index) {
          final filter = activeFilters[index];
          String label = '';
          if (filter['value'] is String) label = filter['value'];
          if (filter['value'] is Tag) label = (filter['value'] as Tag).name;
          if (filter['value'] is Person)
            label = (filter['value'] as Person).name;
          if (filter['type'] == 'type')
            label = label == 'income' ? 'Income' : 'Expense';

          // return Chip(
          //   label: Text(label),
          //   padding: const EdgeInsets.symmetric(horizontal: 4),
          //   onDeleted: () {
          //     TransactionFilter newFilter = _filter;
          //     switch (filter['type']) {
          //       case 'type':
          //         newFilter = newFilter.copyWith(type: () => null);
          //         break;
          //       case 'category':
          //         newFilter = newFilter.copyWith(categories: () => null);
          //         break;
          //       case 'paymentMethod':
          //         newFilter = newFilter.copyWith(paymentMethods: () => null);
          //         break;
          //       case 'tag':
          //         newFilter = newFilter.copyWith(tags: () => null);
          //         break;
          //       case 'person':
          //         newFilter = newFilter.copyWith(people: () => null);
          //         break;
          //     }
          //     _updateFilter(newFilter);
          //   },
          // );

          return _CustomFilterLabelButton(onTap: () {
              TransactionFilter newFilter = _filter;
              switch (filter['type']) {
                case 'type':
                  newFilter = newFilter.copyWith(type: () => null);
                  break;
                case 'category':
                  newFilter = newFilter.copyWith(categories: () => null);
                  break;
                case 'paymentMethod':
                  newFilter = newFilter.copyWith(paymentMethods: () => null);
                  break;
                case 'tag':
                  newFilter = newFilter.copyWith(tags: () => null);
                  break;
                case 'person':
                  newFilter = newFilter.copyWith(people: () => null);
                  break;
              }
              _updateFilter(newFilter);
            }, label: label);
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  Widget _buildChartSection(List<TransactionModel> allTransactions) {
    final year = _selectedYear ?? DateTime.now().year;
    final chartData = _processChartData(allTransactions, year);

    if (!chartData.hasData) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    String title = year.toString();
    final filters = _filter;
    if (filters.categories?.isNotEmpty == true)
      title = filters.categories!.first;
    else if (filters.paymentMethods?.isNotEmpty == true)
      title = filters.paymentMethods!.first;
    else if (filters.tags?.isNotEmpty == true)
      title = filters.tags!.first.name;
    else if (filters.people?.isNotEmpty == true)
      title = filters.people!.first.name;
    else if (filters.type != null)
      title = (filters.type == 'income' ? 'Income' : 'Expense') + ' Overview';

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: _buildSingleLineChart(chartData, title: title),
      ),
    );
  }

  Widget _buildSingleLineChart(ChartData data, {required String title}) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    LineChartBarData buildLineBarData(
      List<FlSpot> spots,
      Color color, {
      bool isBalance = false,
    }) {
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: isBalance ? 4 : 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: data.minY,
                  maxY: data.maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      // tooltipBgColor: colorScheme.primary,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          if (spot.y == 0 && spot.x != spot.x.roundToDouble())
                            return null;
                          return LineTooltipItem(
                            NumberFormat.currency(
                              symbol: '₹',
                              decimalDigits: 0,
                            ).format(spot.y),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes
                          .map((spotIndex) {
                            final spot = barData.spots[spotIndex];
                            if (spot.y == 0 && spot.x != spot.x.roundToDouble())
                              return null;
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                getDotPainter:
                                    (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                  radius: 6,
                                  color: colorScheme.primary,
                                  strokeWidth: 2,
                                  strokeColor:
                                      colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            );
                          })
                          .whereType<TouchedSpotIndicatorData>()
                          .toList();
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > 11)
                            return const SizedBox.shrink();
                          const months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              months[value.round().toInt()],
                              style: textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    if (_filter.type != 'income' && data.expenseSpots.any((s) => !s.x.isNaN))
                      buildLineBarData(data.expenseSpots, appColors.expense),
                    if (_filter.type != 'expense' && data.incomeSpots.any((s) => !s.x.isNaN))
                      buildLineBarData(data.incomeSpots, appColors.income),
                    if (_filter.type == null)
                      buildLineBarData(data.balanceSpots, colorScheme.onSurface, isBalance: true),
                  ],
                ),
                duration: 500.ms,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final result = _result!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Transactions', style: textTheme.headlineMedium),
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Theme.of(context).colorScheme.surface,
            pinned: true,
            floating: true,
            actions: [
              if (_filter.hasActiveFilters)
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded),
                  tooltip: 'Clear All Filters',
                  onPressed: () {
                    _updateFilter(TransactionFilter.empty);
                    setState(() {
                      _selectedFilterType = null;
                      _selectedMonth = null;
                      _selectedYear = DateTime.now().year;
                    });
                    _updateDateFilter(year: DateTime.now().year);
                  },
                ),
            ],
          ),
          _buildChartSection(
            Provider.of<TransactionProvider>(
              context,
              listen: false,
            ).transactions,
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              height: 120 + 48 + 25,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    _SummaryCard(result: result),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          _CustomActionButton(
                            onTap: _showDateFilterModal,
                            label: _getDateFilterLabel(),
                            icon: Icons.calendar_today_rounded,
                          ),
                          const SizedBox(width: 8),
                          _CustomActionButton(
                            onTap: _showFilterModal,
                            label: 'Filters',
                            icon: Icons.filter_list_rounded,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _buildActiveFilters()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Center(
                        child: Text(
                          _getFormattedDateRangeLabel(),
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (result.transactions.isEmpty)
            SliverFillRemaining(child: const _EmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = result.transactions[index];
                  return TransactionListItem(
                    transaction: tx,
                    onTap: () => _showTransactionDetails(context, tx),
                  )
                      .animate()
                      .fade(delay: (50 * index).ms, duration: 200.ms)
                      .slideY(begin: 0.1);
                },
                childCount: result.transactions.length,
              ),
            ),
        ],
      ),
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _StickyHeaderDelegate({required this.child, required this.height});
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;
  @override
  double get maxExtent => height;
  @override
  double get minExtent => height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class _FilterModalContent extends StatefulWidget {
  final TransactionFilter initialFilter;
  final Function(TransactionFilter) onApply;
  const _FilterModalContent({
    required this.initialFilter,
    required this.onApply,
  });
  @override
  State<_FilterModalContent> createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<_FilterModalContent> {
  late String? tempType;
  late String? tempCategory;
  late String? tempPaymentMethod;
  late Tag? tempTag;
  late Person? tempPerson;
  bool isAllPeopleSelected = false;

  @override
  void initState() {
    super.initState();
    tempType = widget.initialFilter.type;
    tempCategory = widget.initialFilter.categories?.isNotEmpty == true
        ? widget.initialFilter.categories!.first
        : null;
    tempPaymentMethod = widget.initialFilter.paymentMethods?.isNotEmpty == true
        ? widget.initialFilter.paymentMethods!.first
        : null;
    tempTag = widget.initialFilter.tags?.isNotEmpty == true
        ? widget.initialFilter.tags!.first
        : null;
    tempPerson = widget.initialFilter.people?.isNotEmpty == true
        ? widget.initialFilter.people!.first
        : null;
    if (tempCategory == 'People' && tempPerson == null) {
      isAllPeopleSelected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final textTheme = Theme.of(context).textTheme;
    final allCategories =
        ({
      ...TransactionCategories.income,
      ...TransactionCategories.expense,
    }.toList()
          ..remove('People')
          ..sort());
    final allPaymentMethods = ['Cash', 'Card', 'UPI', 'Net Banking'];
    final allTags = metaProvider.tags;
    final allPeople = metaProvider.people;

    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Details', style: textTheme.headlineMedium),
                  TextButton(
                    onPressed: () => setState(() {
                      tempType = null;
                      tempCategory = null;
                      tempPaymentMethod = null;
                      tempTag = null;
                      tempPerson = null;
                      isAllPeopleSelected = false;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Type', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String?>(
                  multiSelectionEnabled: false,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                  ],
                  selected: {tempType},
                  onSelectionChanged: (newSelection) =>
                      setState(() => tempType = newSelection.first),
                ),
              ),
              const SizedBox(height: 24),
              Text('Categories', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCategories.map((category) {
                  return FilterChip(
                    label: Text(category),
                    selected: tempCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        tempCategory = selected ? category : null;
                        if (selected) {
                          tempPerson = null;
                          isAllPeopleSelected = false;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Payment Methods', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allPaymentMethods.map((method) {
                  return FilterChip(
                    label: Text(method),
                    selected: tempPaymentMethod == method,
                    onSelected: (selected) => setState(
                      () => tempPaymentMethod = selected ? method : null,
                    ),
                  );
                }).toList(),
              ),
              if (allTags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Tags', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    return FilterChip(
                      label: Text(tag.name),
                      selected: tempTag?.id == tag.id,
                      onSelected: (selected) =>
                          setState(() => tempTag = selected ? tag : null),
                    );
                  }).toList(),
                ),
              ],
              if (allPeople.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('People', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All People'),
                      selected: isAllPeopleSelected,
                      onSelected: (selected) {
                        setState(() {
                          isAllPeopleSelected = selected;
                          if (selected) {
                            tempPerson = null;
                            tempCategory = 'People';
                          } else if (tempCategory == 'People') {
                            tempCategory = null;
                          }
                        });
                      },
                    ),
                    ...allPeople.map((person) {
                      return FilterChip(
                        label: Text(person.name),
                        selected: tempPerson?.id == person.id,
                        onSelected: (selected) {
                          setState(() {
                            tempPerson = selected ? person : null;
                            if (selected) {
                              isAllPeopleSelected = false;
                              tempCategory = null;
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final newFilter = TransactionFilter(
                      type: tempType,
                      categories:
                          tempCategory == null ? null : [tempCategory!],
                      paymentMethods: tempPaymentMethod == null
                          ? null
                          : [tempPaymentMethod!],
                      tags: tempTag == null ? null : [tempTag!],
                      people: tempPerson == null ? null : [tempPerson!],
                      startDate: widget.initialFilter.startDate,
                      endDate: widget.initialFilter.endDate,
                    );
                    widget.onApply(newFilter);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateFilterModalContent extends StatefulWidget {
  final DateFilterType? initialFilterType;
  final int? initialYear;
  final int? initialMonth;
  final DateTimeRange? initialCustomRange;
  final List<int> availableYears;
  final Function(DateFilterType?, int?, int?, DateTimeRange?) onApply;
  const _DateFilterModalContent({
    required this.initialFilterType,
    required this.initialYear,
    required this.initialMonth,
    required this.initialCustomRange,
    required this.availableYears,
    required this.onApply,
  });
  @override
  State<_DateFilterModalContent> createState() =>
      _DateFilterModalContentState();
}

class _DateFilterModalContentState extends State<_DateFilterModalContent> {
  late DateFilterType? tempFilterType;
  late int? tempYear;
  late int? tempMonth;
  late DateTimeRange? tempCustomRange;
  @override
  void initState() {
    super.initState();
    tempFilterType = widget.initialFilterType;
    tempYear = widget.initialYear;
    tempMonth = widget.initialMonth;
    tempCustomRange = widget.initialCustomRange;
  }

  void handleSelection({DateFilterType? type, int? year, int? month}) {
    setState(() {
      final now = DateTime.now();
      if (type != null) {
        tempFilterType = tempFilterType == type ? null : type;
        tempYear = null;
        tempMonth = null;
        if (tempFilterType == null) tempYear = now.year;
      } else if (month != null) {
        tempFilterType = null;
        tempMonth = tempMonth == month ? null : month;
        tempYear ??= now.year;
      } else if (year != null) {
        tempFilterType = null;
        tempYear = tempYear == year ? null : year;
        tempMonth = null;
        if (tempYear == null) tempFilterType = DateFilterType.today;
      }
    });
  }

  Future<void> pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      initialDateRange: tempCustomRange,
    );
    if (picked != null) {
      setState(() {
        tempFilterType = DateFilterType.custom;
        tempYear = null;
        tempMonth = null;
        tempCustomRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Date Range',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                iconSize: 32,
                tooltip: 'Apply',
                onPressed: () {
                  widget.onApply(
                    tempFilterType,
                    tempYear,
                    tempMonth,
                    tempCustomRange,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DateFilterSection(
            selectedFilterType: tempFilterType,
            selectedMonth: tempMonth,
            selectedYear: tempYear,
            availableYears: widget.availableYears,
            onTypeSelected: (type) => handleSelection(type: type),
            onMonthSelected: (month) => handleSelection(month: month),
            onYearSelected: (year) => handleSelection(year: year),
            onCustomDateTap: pickCustomDate,
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ],
      ),
    );
  }
}

class _DateFilterSection extends StatelessWidget {
  final DateFilterType? selectedFilterType;
  final int? selectedYear;
  final int? selectedMonth;
  final List<int> availableYears;
  final Function(DateFilterType) onTypeSelected;
  final Function(int) onYearSelected;
  final Function(int) onMonthSelected;
  final VoidCallback onCustomDateTap;
  const _DateFilterSection({
    required this.selectedFilterType,
    required this.selectedYear,
    required this.selectedMonth,
    required this.availableYears,
    required this.onTypeSelected,
    required this.onYearSelected,
    required this.onMonthSelected,
    required this.onCustomDateTap,
  });
  @override
  Widget build(BuildContext context) {
    final timeframes = {
      'Today': DateFilterType.today,
      'Yesterday': DateFilterType.yesterday,
      'This Week': DateFilterType.thisWeek,
      'Last Week': DateFilterType.lastWeek,
      'This Month': DateFilterType.thisMonth,
      'Last Month': DateFilterType.lastMonth,
      'This Quarter': DateFilterType.thisQuarter,
      'Last Quarter': DateFilterType.lastQuarter,
      'This Fiscal Year': DateFilterType.thisFiscalYear,
      'Last Fiscal Year': DateFilterType.lastFiscalYear,
    };
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...timeframes.entries.map(
                (entry) => _CustomFilterChip(
                  label: entry.key,
                  isSelected: selectedFilterType == entry.value,
                  onTap: () => onTypeSelected(entry.value),
                ),
              ),
              _CustomFilterChip(
                label: 'Custom',
                isSelected: selectedFilterType == DateFilterType.custom,
                onTap: onCustomDateTap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...months.entries.map(
                (entry) => _CustomFilterChip(
                  label: entry.key,
                  isSelected: selectedMonth == entry.value,
                  onTap: () => onMonthSelected(entry.value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableYears
                .map(
                  (year) => _CustomFilterChip(
                    label: year.toString(),
                    isSelected: selectedYear == year,
                    onTap: () => onYearSelected(year),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CustomFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: isSelected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 4),
                  const Icon(Icons.cancel, size: 16),
                ],
              )
            : Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: isSelected
            ? TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)
            : null,
      ),
    );
  }
}

class _CustomActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _CustomActionButton({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: colorScheme.primaryContainer.withAlpha(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomFilterLabelButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _CustomFilterLabelButton({
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      // borderRadius: BorderRadius.circular(16),
      // borderOnForeground: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.onSurfaceVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: colorScheme.primaryContainer.withAlpha(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.cancel_rounded, size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}



class _SummaryCard extends StatelessWidget {
  final FilterResult result;
  const _SummaryCard({required this.result});
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryColumn(
              title: 'Income',
              amount: currencyFormat.format(result.totalIncome),
              isIncome: true,
            ),
            _SummaryColumn(
              title: 'Expense',
              amount: currencyFormat.format(result.totalExpense),
              isExpense: true,
            ),
            _SummaryColumn(
              title: 'Balance',
              amount: currencyFormat.format(result.balance),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String title;
  final String amount;
  final bool isIncome;
  final bool isExpense;
  const _SummaryColumn({
    required this.title,
    required this.amount,
    this.isIncome = false,
    this.isExpense = false,
  });
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    Color amountColor;
    if (isIncome) {
      amountColor = appColors.income;
    } else if (isExpense) {
      amountColor = appColors.expense;
    } else {
      final balance =
          double.tryParse(amount.replaceAll(RegExp(r'[₹,]'), '')) ?? 0.0;
      amountColor = balance >= 0
          ? Theme.of(context).colorScheme.onSurface
          : appColors.expense;
    }
    return Column(
      children: [
        Text(title, style: textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(amount, style: textTheme.titleLarge?.copyWith(color: amountColor)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

extension _DateHelpers on _AllTransactionsScreenState {
  DateTimeRange _getRangeForType(DateFilterType type) {
    final now = DateTime.now();
    switch (type) {
      case DateFilterType.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case DateFilterType.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(yesterday.year, yesterday.month, yesterday.day),
          end: DateTime(yesterday.year, yesterday.month, yesterday.day),
        );
      case DateFilterType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: now,
        );
      case DateFilterType.lastWeek:
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        final startOfLastWeek = endOfLastWeek.subtract(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(
            startOfLastWeek.year,
            startOfLastWeek.month,
            startOfLastWeek.day,
          ),
          end: DateTime(
            endOfLastWeek.year,
            endOfLastWeek.month,
            endOfLastWeek.day,
          ),
        );
      case DateFilterType.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case DateFilterType.lastMonth:
        final firstDayOfThisMonth = DateTime(now.year, now.month, 1);
        final endOfLastMonth = firstDayOfThisMonth.subtract(
          const Duration(days: 1),
        );
        final startOfLastMonth = DateTime(
          endOfLastMonth.year,
          endOfLastMonth.month,
          1,
        );
        return DateTimeRange(start: startOfLastMonth, end: endOfLastMonth);
      case DateFilterType.thisQuarter:
        final quarter = (now.month - 1) ~/ 3 + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        final startOfQuarter = DateTime(now.year, startMonth, 1);
        return DateTimeRange(start: startOfQuarter, end: now);
      case DateFilterType.lastQuarter:
        final currentQuarter = (now.month - 1) ~/ 3 + 1;
        final startMonthOfCurrentQuarter = (currentQuarter - 1) * 3 + 1;
        final endOfLastQuarter = DateTime(
          now.year,
          startMonthOfCurrentQuarter,
          1,
        ).subtract(const Duration(days: 1));
        final startOfLastQuarter = DateTime(
          endOfLastQuarter.year,
          endOfLastQuarter.month - 2,
          1,
        );
        return DateTimeRange(start: startOfLastQuarter, end: endOfLastQuarter);
      case DateFilterType.thisFiscalYear:
        final startYear = (now.month < 4) ? now.year - 1 : now.year;
        return DateTimeRange(start: DateTime(startYear, 4, 1), end: now);
      case DateFilterType.lastFiscalYear:
        final startYearOfCurrent = (now.month < 4) ? now.year - 1 : now.year;
        final startOfLastFiscalYear = DateTime(startYearOfCurrent - 1, 4, 1);
        final endOfLastFiscalYear = DateTime(startYearOfCurrent, 3, 31);
        return DateTimeRange(
          start: startOfLastFiscalYear,
          end: endOfLastFiscalYear,
        );
      case DateFilterType.custom:
        return DateTimeRange(
          start: _filter.startDate ?? now,
          end: _filter.endDate?.subtract(const Duration(days: 1)) ?? now,
        );
    }
  }

  DateTimeRange _getYearRange(int year) {
    return DateTimeRange(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
  }

  DateTimeRange _getMonthRange(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = (month == 12)
        ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
        : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    return DateTimeRange(start: firstDay, end: lastDay);
  }
}