import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/summary/widgets/summary_content_view.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TimedSummaryScreen extends StatefulWidget {
  final DateTime? initialDate;
  const TimedSummaryScreen({super.key, this.initialDate});

  static const bool allowTestMode = true;

  @override
  State<TimedSummaryScreen> createState() => _TimedSummaryScreenState();
}

class _TimedSummaryScreenState extends State<TimedSummaryScreen> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your ${_getFullMonthName(_currentDate.month)} Summary',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Consumer2<TransactionProvider, SettingsProvider>(
        builder: (context, txProvider, settingsProvider, child) {
          final budgetCycleRange = BudgetCycleHelper.getCycleRange(
            targetMonth: _currentDate.month,
            targetYear: _currentDate.year,
            mode: settingsProvider.budgetCycleMode,
            startDay: settingsProvider.budgetCycleStartDay,
          );

          final monthlyTransactions = txProvider.transactions.where((tx) {
            return !tx.timestamp.isBefore(budgetCycleRange.start) &&
                tx.timestamp.isBefore(budgetCycleRange.end);
          }).toList();

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).colorScheme.surfaceContainerLow,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SummaryContentView(
              transactions: monthlyTransactions,
              monthDate: _currentDate,
              onTransactionTap: (tx) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TransactionDetailScreen(transaction: tx),
                );
              },
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  String _getFullMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
