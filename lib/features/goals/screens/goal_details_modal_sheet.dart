import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/goals/models/goal_model.dart';
import 'package:wallzy/features/goals/provider/goals_provider.dart';
import 'package:wallzy/features/goals/screens/add_edit_goal_screen.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';

class GoalDetailsModalSheet extends StatelessWidget {
  final Goal goal;

  const GoalDetailsModalSheet({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer3<GoalsProvider, AccountProvider, TransactionProvider>(
      builder: (context, goalsProvider, accountProvider, txProvider, child) {
        // Re-fetch goal from provider to get latest state
        final Goal currentGoal = goalsProvider.goals.firstWhere(
          (g) => g.id == goal.id,
          orElse: () => goal,
        );

        final transactions = txProvider.transactions;
        final accounts = accountProvider.accounts;
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final currencySymbol = settingsProvider.currencySymbol;

        // Calculate Progress
        double currentAmount = 0.0;
        if (currentGoal.accountsList.isEmpty) {
          currentAmount = accountProvider.getTotalAvailableCash(transactions);
        } else {
          for (var accId in currentGoal.accountsList) {
            try {
              final account = accounts.firstWhere((a) => a.id == accId);
              currentAmount += accountProvider.getBalanceForAccount(
                account,
                transactions,
              );
            } catch (_) {}
          }
        }

        final remaining = (currentGoal.targetAmount - currentAmount).clamp(
          0.0,
          double.infinity,
        );
        final progressPercent = (currentAmount / currentGoal.targetAmount)
            .clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withAlpha(50),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      children: [
                        // --- PROGRESS PIE CHART ---
                        SizedBox(
                          height: 140,
                          width: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              LedgrPieChart(
                                thickness: 16,
                                gap: 0,
                                sections: [
                                  PieData(
                                    value: currentAmount.clamp(
                                      0.0,
                                      currentGoal.targetAmount,
                                    ),
                                    color: colorScheme.primary,
                                  ),
                                  PieData(
                                    value: remaining,
                                    color: colorScheme.primary.withAlpha(50),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: GoalIconRegistry.getIcon(
                                      currentGoal.iconKey,
                                    ),
                                    size: 32,
                                    color: colorScheme.onSurface,
                                    strokeWidth: 2,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${(progressPercent * 100).toInt()}%",
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'momo',
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- TITLE ---
                        Text(
                          currentGoal.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // --- TARGET AMOUNT & DATE ---
                        Text(
                          "${NumberFormat.simpleCurrency(name: currencySymbol).format(currentGoal.targetAmount)}  •  ${DateFormat.yMMMd().format(currentGoal.targetDate)}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- SAVED VS REMAINING ROW ---
                        Row(
                          children: [
                            Expanded(
                              child: _DetailBox(
                                label: "SAVED",
                                value: NumberFormat.compactSimpleCurrency(
                                  name: currencySymbol,
                                ).format(currentAmount),
                                icon: HugeIcons.strokeRoundedTick02,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DetailBox(
                                label: "REMAINING",
                                value: NumberFormat.compactSimpleCurrency(
                                  name: currencySymbol,
                                ).format(remaining),
                                icon: HugeIcons.strokeRoundedClock01,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),

                        // --- DESCRIPTION ---
                        if (currentGoal.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoCard(
                            title: "DESCRIPTION",
                            content: currentGoal.description,
                            icon: HugeIcons.strokeRoundedNote01,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ],

                        // --- LINKED ACCOUNTS ---
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: "TRACKING ACCOUNTS",
                          icon: HugeIcons.strokeRoundedWallet01,
                          colorScheme: colorScheme,
                          theme: theme,
                          child: currentGoal.accountsList.isEmpty
                              ? const Text(
                                  "Currently tracking all accounts",
                                  style: TextStyle(height: 1.4),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: currentGoal.accountsList.map((id) {
                                    final acc = accounts.firstWhere(
                                      (a) => a.id == id,
                                      orElse: () => Account(
                                        id: '',
                                        bankName: 'Deleted Account',
                                        accountNumber: '',
                                        userId: '',
                                        accountHolderName: '',
                                      ),
                                    );
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        acc.bankName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),

                        const SizedBox(height: 32),

                        // --- ACTIONS ---
                        Row(
                          children: [
                            Expanded(
                              child: _ActionBox(
                                label: "Edit",
                                icon: HugeIcons.strokeRoundedEdit02,
                                color: colorScheme.primary,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddEditGoalScreen(goal: currentGoal),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionBox(
                                label: "Delete",
                                icon: HugeIcons.strokeRoundedDelete02,
                                color: colorScheme.error,
                                isDestructive: true,
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Goal?'),
                                      content: const Text(
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await goalsProvider.deleteGoal(
                                      currentGoal.id,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailBox extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;

  const _DetailBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.outline,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontFamily: 'momo',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? child;
  final dynamic icon;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _InfoCard({
    required this.title,
    this.content,
    this.child,
    required this.icon,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 16, color: colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.outline,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (child != null) child!,
          if (content != null)
            Text(
              content!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBox extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionBox({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive
              ? color.withAlpha(20)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: isDestructive
              ? null
              : Border.all(color: colorScheme.outlineVariant.withAlpha(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icon, color: color, size: 20, strokeWidth: 2),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
