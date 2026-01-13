import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

class BudgetHelper {
  /// Calculates the total amount spent for a given [tag] within its current budget period.
  ///
  /// Uses [settings] to determine the correct date range for "Monthly" budgets
  /// based on the user's customized budget cycle.
  static double calculateSpent(
    Tag tag,
    List<TransactionModel> allTransactions,
    SettingsProvider settings,
  ) {
    // 1. If no budget is set, technically "spent" is all-time or irrelevant,
    // but usually we only want to show this if a budget exists.
    // However, the caller checks budget > 0. We'll return 0 if no budget just in case.
    if ((tag.tagBudget ?? 0) <= 0) return 0.0;

    // 2. Determine Date Range
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    final frequency = tag.tagBudgetFrequency ?? TagBudgetResetFrequency.never;

    switch (frequency) {
      case TagBudgetResetFrequency.daily:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;

      case TagBudgetResetFrequency.weekly:
        // Assume Monday start for simplicity unless settings specify otherwise later.
        // Or standard ISO 8601: Monday = 1.
        // If today is Monday (1), subtract 0 days.
        // If today is Sunday (7), subtract 6 days.
        final diff = now.weekday - 1;
        final startOfThisWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: diff));
        start = startOfThisWeek;
        end = start.add(const Duration(days: 7));
        break;

      case TagBudgetResetFrequency.monthly:
        // Use BudgetCycleHelper for custom monthly cycles
        final range = BudgetCycleHelper.getCycleRange(
          targetMonth: now.month,
          targetYear: now.year,
          mode: settings.budgetCycleMode,
          startDay: settings.budgetCycleStartDay,
        );
        start = range.start;
        end = range.end;
        break;

      case TagBudgetResetFrequency.quarterly:
        // Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec
        int quarter = ((now.month - 1) / 3).floor();
        start = DateTime(now.year, quarter * 3 + 1, 1);
        end = DateTime(now.year, quarter * 3 + 4, 1);
        break;

      case TagBudgetResetFrequency.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;

      case TagBudgetResetFrequency.never:
        // All time: Start is epoch, End is far future
        start = DateTime(1970);
        end = DateTime(3000);
        break;
    }

    // 3. Delegate to Net Spend Calculation
    return calculateNetSpentForRange(tag, allTransactions, start, end);
  }

  /// Calculates the net spent (Expense - Income) for a specific date range.
  static double calculateNetSpentForRange(
    Tag tag,
    List<TransactionModel> allTransactions,
    DateTime start,
    DateTime end,
  ) {
    double spent = 0.0;
    for (var tx in allTransactions) {
      // Must be in this tag (optimization: check tag first)
      if (tx.tags == null || !tx.tags!.any((t) => t.id == tag.id)) {
        continue;
      }

      // Check date range
      bool inRange =
          tx.timestamp.isAtSameMomentAs(start) ||
          (tx.timestamp.isAfter(start) && tx.timestamp.isBefore(end));

      if (!inRange) continue;

      if (tx.type == 'expense') {
        spent += tx.amount;
      } else if (tx.type == 'income') {
        spent -= tx.amount;
      }
    }
    return spent;
  }
}
