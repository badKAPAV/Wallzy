import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/dashboard/models/home_widget_model.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';
import 'package:wallzy/features/dashboard/home_widgets/folder_watchlist/folder_selection_sheet.dart';
import 'package:wallzy/features/tag/services/budget_helper.dart';

class FolderWatchlistWidget extends StatelessWidget {
  final HomeWidgetModel model;
  const FolderWatchlistWidget({super.key, required this.model});

  void _showFolderSelectionSheet(BuildContext context, HomeWidgetModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FolderSelectionSheet(
        widgetId: model.id,
        initialSelection: model.configIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Real Data
    final metaProvider = Provider.of<MetaProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final allTags = metaProvider.tags;
    final selectedTags = allTags
        .where((t) => model.configIds.contains(t.id) && (t.tagBudget ?? 0) > 0)
        .toList();

    final folders = selectedTags.map((tag) {
      final netSpent = BudgetHelper.calculateSpent(
        tag,
        transactionProvider.transactions,
        settingsProvider,
      );

      return _FolderData(
        id: tag.id,
        name: tag.name,
        color: tag.color != null ? Color(tag.color!) : Colors.blue,
        spent: netSpent,
        limit: tag.tagBudget ?? 0.0,
        frequency: tag.tagBudgetFrequency?.name.toUpperCase() ?? 'MONTHLY',
      );
    }).toList();

    // 2. Determine Layout Mode
    // Even though resizing is disabled, we still support responsive layout
    final isCompact = model.width == 2;
    final textTheme = Theme.of(context).textTheme;

    final currencySymbol = settingsProvider.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            physics: const NeverScrollableScrollPhysics(),
            // Show up to 3 items + potential Add button
            itemCount: folders.length < 3 ? folders.length + 1 : folders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == folders.length) {
                return InkWell(
                  onTap: () => _showFolderSelectionSheet(context, model),
                  borderRadius: BorderRadius.circular(12),
                  child: DashedBorder(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    strokeWidth: 1.5,
                    gap: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 30,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Add another",
                            style: textTheme.labelMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final folder = folders[index];
              // Avoid division by zero
              final percent = folder.limit > 0
                  ? (folder.spent / folder.limit).clamp(0.0, 1.0)
                  : 0.0;

              final spentStr = folder.spent.toStringAsFixed(0);
              final limitStr = folder.limit.toStringAsFixed(0);

              return SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Icon Circle
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: folder.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedFolder02,
                              size: 16,
                              color: folder.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Row: Name and Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            folder.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  height: 1,
                                                  fontSize: 13,
                                                ),
                                          ),
                                        ),
                                        if (!isCompact &&
                                            folder.frequency != 'NEVER') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              folder.frequency,
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '$currencySymbol$spentStr',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'momo',
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        " / $limitStr",
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).hintColor,
                                          fontFamily: 'momo',
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // const SizedBox(height: 4),

                              // Bottom Row: Progress Bar and %
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 4,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        color:
                                            folder.limit > 0 && percent > 0.95
                                            ? Colors.red
                                            : folder.color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(percent * 100).toInt()}%",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolderData {
  final String id;
  final String name;
  final Color color;
  final double spent;
  final double limit;
  final String frequency;
  _FolderData({
    required this.id,
    required this.name,
    required this.color,
    required this.spent,
    required this.limit,
    required this.frequency,
  });
}
