import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/budget_helper.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/tag/widgets/add_edit_folder_budget_modal_sheet.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/tag/widgets/tag_budget_history_sheet.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:hugeicons/hugeicons.dart';

class TagBudgetCard extends StatelessWidget {
  final Tag tag;

  const TagBudgetCard({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    if ((tag.tagBudget ?? 0) <= 0) return const SizedBox.shrink();

    return Consumer2<TransactionProvider, SettingsProvider>(
      builder: (context, txProvider, settings, child) {
        final spent = BudgetHelper.calculateSpent(
          tag,
          txProvider.transactions,
          settings,
        );
        final budget = tag.tagBudget!;
        final remaining = budget - spent;
        final isOverspent = spent > budget;
        final isNearLimit = !isOverspent && spent >= (budget * 0.9);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        // Tag Color
        final tagColor = tag.color != null
            ? Color(tag.color!)
            : colorScheme.primary;

        final colorToUse = isOverspent ? colorScheme.error : tagColor;

        final sections = [
          PieData(
            value: spent.clamp(0.0, budget), // Cap at budget for visual
            color: colorToUse,
          ),
          PieData(
            value: remaining > 0 ? remaining : 0,
            color: colorToUse.withAlpha(30),
          ),
        ];

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return AddEditFolderBudgetModalSheet(tag: tag);
              },
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isOverspent
                    ? colorScheme.error.withAlpha(100)
                    : theme.colorScheme.outlineVariant.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Folder Budget",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOverspent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: colorScheme.onErrorContainer,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Overspent",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isNearLimit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "Near Limit",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return TagBudgetHistorySheet(tag: tag);
                          },
                        );
                      },
                      icon: Icon(
                        Icons.history_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content Row
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            LedgrPieChart(
                              sections: sections,
                              thickness: 16,
                              gap: 0,
                              // We are manually providing the "remaining" section, so background empty color doesn't matter much
                              // unless we want a specific track color.
                              emptyColor: Colors.transparent,
                            ),
                            HugeIcon(
                              icon: GoalIconRegistry.getFolderIcon(tag.iconKey),
                              size: 24,
                              color: colorToUse,
                              strokeWidth: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Values
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              settings.currencySymbol + _formatAmount(spent),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isOverspent ? colorScheme.error : null,
                              ),
                            ),
                            Text(
                              "of ${settings.currencySymbol}${_formatAmount(budget)} limit",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getFrequencyText(tag.tagBudgetFrequency),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return NumberFormat.compact().format(amount);
    }
    return NumberFormat.decimalPattern().format(amount);
  }

  String _getFrequencyText(TagBudgetResetFrequency? freq) {
    switch (freq) {
      case TagBudgetResetFrequency.daily:
        return "Resets Daily";
      case TagBudgetResetFrequency.weekly:
        return "Resets Weekly";
      case TagBudgetResetFrequency.monthly:
        return "Resets Monthly";
      case TagBudgetResetFrequency.quarterly:
        return "Resets Quarterly";
      case TagBudgetResetFrequency.yearly:
        return "Resets Yearly";
      default:
        return "Total Budget";
    }
  }
}
