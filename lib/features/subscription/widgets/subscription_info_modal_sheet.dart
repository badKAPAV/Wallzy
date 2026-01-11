import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/common/widgets/tile_data_widgets.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:collection/collection.dart';

class SubscriptionInfoModalSheet extends StatelessWidget {
  final Subscription subscription;

  const SubscriptionInfoModalSheet({super.key, required this.subscription});

  Subscription _getCurrentSubscription(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    return provider.subscriptions.firstWhere(
      (s) => s.id == subscription.id,
      orElse: () => subscription,
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final currentObj = _getCurrentSubscription(context);
    final isArchived = !currentObj.isActive;

    if (isArchived) {
      _restoreSubscription(context);
    } else {
      _showArchiveDialog(context);
    }
  }

  void _showArchiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: "Archive Subscription",
        description: "Are you sure you want to archive this subscription?",
        icon: HugeIcons.strokeRoundedArchive03,
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
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            child: const Text(
              "Archive",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<SubscriptionProvider>(
                context,
                listen: false,
              ).archiveSubscription(subscription.id);
              Navigator.pop(context); // Close modal
            },
          ),
        ],
      ),
    );
  }

  void _restoreSubscription(BuildContext context) {
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
              Navigator.pop(ctx);
              Provider.of<SubscriptionProvider>(
                context,
                listen: false,
              ).restoreSubscription(subscription.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showPauseOptions(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final currentObj = _getCurrentSubscription(context);

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
                Navigator.pop(context); // Close info modal too?
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
                Navigator.pop(context); // Close info modal too?
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to get updates?
    // The modal is usually static or dismisses on action.
    // However, if we want to show updated status (e.g. after resume), we might want to watch.
    // But typically modals are transient.
    final currentObj = _getCurrentSubscription(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPaused = currentObj.pauseState != SubscriptionPauseState.active;
    final isArchived = !currentObj.isActive;

    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    String methodDisplay = currentObj.paymentMethod;
    if (currentObj.accountId != null) {
      final account = accountProvider.accounts.firstWhereOrNull(
        (a) => a.id == currentObj.accountId,
      );
      if (account != null) {
        methodDisplay = '$methodDisplay (${account.bankName})';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Visual Card
                  _SubscriptionVisualCard(subscription: currentObj),
                  const SizedBox(height: 24),

                  // 2. Action Buttons
                  Row(
                    children: [
                      if (!isArchived)
                        Expanded(
                          child: ActionBox(
                            label: isPaused ? "Resume" : "Pause",
                            icon: isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: isPaused
                                ? colorScheme.primary
                                : colorScheme.secondary,
                            onTap: () {
                              if (isPaused) {
                                Provider.of<SubscriptionProvider>(
                                  context,
                                  listen: false,
                                ).updateSubscription(
                                  currentObj.copyWith(
                                    pauseState: SubscriptionPauseState.active,
                                  ),
                                );
                                Navigator.pop(context);
                              } else {
                                _showPauseOptions(context);
                              }
                            },
                          ),
                        ),
                      if (!isArchived) const SizedBox(width: 12),
                      Expanded(
                        child: ActionBox(
                          label: "Edit",
                          icon: Icons.edit_rounded,
                          color: colorScheme.primary,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddSubscriptionScreen(
                                  subscription: currentObj,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionBox(
                          label: isArchived ? "Restore" : "Archive",
                          icon: isArchived
                              ? Icons.settings_backup_restore_rounded
                              : Icons.archive_outlined,
                          color: isArchived
                              ? colorScheme.primary
                              : colorScheme.error,
                          onTap: () => _showDeleteConfirmation(context),
                          isDestructive: !isArchived,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. Data Grid
                  Text(
                    "Subscription Details",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 1
                  SizedBox(
                    height: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: DataTile(
                            label: "Frequency",
                            value: currentObj.frequency.name.toUpperCase(),
                            icon: Icons.repeat_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DataTile(
                            label: "Next Due Date",
                            value: DateFormat(
                              'MMM d, y',
                            ).format(currentObj.nextDueDate),
                            icon: Icons.calendar_today_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 2
                  SizedBox(
                    height: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: DataTile(
                            label: "Category",
                            value: currentObj.category,
                            icon: Icons.category_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DataTile(
                            label: "Payment Method",
                            value: methodDisplay,
                            icon: Icons.payment_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Indicator Row (Optional, if we want to show exact status)
                  if (isPaused || isArchived) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: Row(
                        children: [
                          Expanded(
                            child: DataTile(
                              label: "Status",
                              value: isArchived
                                  ? "Archived"
                                  : (isPaused ? "Paused" : "Active"),
                              icon: isArchived
                                  ? Icons.archive_rounded
                                  : (isPaused
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.check_circle_rounded),
                            ),
                          ),
                          // Spacer to fill the row
                          const SizedBox(width: 12),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionVisualCard extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionVisualCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currencySymbol = settingsProvider.currencySymbol;

    // Gradient based on amount or random logic, or just a nice preset
    // AccountVisualCard uses green for cash, blue for credit, primary/tertiary for debit.
    // For subscriptions, maybe a purple/pink gradient or similar to primary.
    final bgGradient = LinearGradient(
      colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final textColor = Colors.white;

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.subscriptions_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "SUBSCRIPTION",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              if (!subscription.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "ARCHIVED",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subscription.name.toUpperCase(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Optional: Show category or simplified info
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NumberFormat.currency(
                  symbol: currencySymbol,
                  decimalDigits: 0,
                ).format(subscription.amount),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "/${subscription.frequency.name == 'biMonthly' ? '2 MO' : (subscription.frequency.name == 'quarterly' ? '3 MO' : (subscription.frequency.name == 'halfYearly' ? '6 MO' : (subscription.frequency.name == 'yearly' ? 'YR' : 'MO')))}",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
