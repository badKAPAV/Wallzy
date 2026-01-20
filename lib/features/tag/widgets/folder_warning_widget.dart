import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/budget_helper.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class FolderWarningWidget extends StatelessWidget {
  const FolderWarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<MetaProvider, TransactionProvider, SettingsProvider>(
      builder: (context, meta, txProvider, settings, child) {
        final allTags = meta.tags;
        final warnings = <_WarningItem>[];

        for (final tag in allTags) {
          // Check if warning is enabled
          if (!meta.isBudgetWarningEnabled(tag.id)) continue;

          final budget = tag.tagBudget ?? 0;
          if (budget <= 0) continue;

          final spent = BudgetHelper.calculateSpent(
            tag,
            txProvider.transactions,
            settings,
          );

          if (spent >= budget * 0.8) {
            warnings.add(_WarningItem(tag: tag, spent: spent, budget: budget));
          }
        }

        if (warnings.isEmpty) return const SizedBox.shrink();

        // Sort: Overspent desc %, then Near Limit desc %
        warnings.sort((a, b) {
          final aPct = a.spent / a.budget;
          final bPct = b.spent / b.budget;
          return bPct.compareTo(aPct);
        });

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 156, // Fixed height for horizontal list
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: warnings.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => _WarningCard(item: warnings[i]),
          ),
        );
      },
    );
  }
}

class _WarningItem {
  final Tag tag;
  final double spent;
  final double budget;

  _WarningItem({required this.tag, required this.spent, required this.budget});
}

class _WarningCard extends StatelessWidget {
  final _WarningItem item;

  const _WarningCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaProvider = Provider.of<MetaProvider>(
      context,
      listen: false,
    ); // Don't rebuild just for callback

    final isOverspent = item.spent > item.budget;
    final tagColor = item.tag.color != null
        ? Color(item.tag.color!)
        : theme.colorScheme.primary;
    final colorToUse = isOverspent ? theme.colorScheme.error : tagColor;

    // Pie Chart Data
    final sections = [
      PieData(value: item.spent.clamp(0.0, item.budget), color: colorToUse),
      PieData(
        value: (item.budget - item.spent).clamp(0.0, item.budget),
        color: colorToUse.withAlpha(50),
      ),
    ];

    return Stack(
      children: [
        Container(
          width: 136,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOverspent
                  ? theme.colorScheme.error.withAlpha(100)
                  : theme.colorScheme.outlineVariant.withAlpha(50),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CHART
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    LedgrPieChart(
                      sections: sections,
                      thickness: 8,
                      gap: 0,
                      emptyColor: Colors.transparent,
                    ),
                    if (isOverspent)
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        color: theme.colorScheme.error,
                        size: 20,
                      )
                    else
                      Text(
                        "${((item.spent / item.budget) * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                isOverspent ? "Overspent" : "Near Limit",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isOverspent ? theme.colorScheme.error : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              metaProvider.setBudgetWarning(item.tag.id, false);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(150),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
