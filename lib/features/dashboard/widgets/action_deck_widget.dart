import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart'; // Assuming AppColors is here
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/due_subscription.dart';
import 'package:hugeicons/hugeicons.dart';

class ActionDeckWidget extends StatefulWidget {
  final List<Map<String, dynamic>> pendingSmsTransactions;
  final List<DueSubscription> dueSubscriptions;
  final Function(Map<String, dynamic>) onPendingSmsTap;
  final Function(Map<String, dynamic>) onPendingSmsDismiss;
  final Function(DueSubscription) onDueSubscriptionTap;
  final Function(DueSubscription) onDueSubscriptionDismiss;
  final VoidCallback onIgnoreAll;
  final VoidCallback onShowAllTap;

  const ActionDeckWidget({
    super.key,
    required this.pendingSmsTransactions,
    required this.dueSubscriptions,
    required this.onPendingSmsTap,
    required this.onPendingSmsDismiss,
    required this.onDueSubscriptionTap,
    required this.onDueSubscriptionDismiss,
    required this.onIgnoreAll,
    required this.onShowAllTap,
  });

  @override
  State<ActionDeckWidget> createState() => _ActionDeckWidgetState();
}

class _ActionDeckWidgetState extends State<ActionDeckWidget> {
  double _actionDeckOverscroll = 0.0;
  bool _isDismissTriggered = false;
  static const double _dismissThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    if (widget.pendingSmsTransactions.isEmpty &&
        widget.dueSubscriptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final appColors = theme.extension<AppColors>();

    // Combine and Sort or Filter data
    final highValueTransactions = widget.pendingSmsTransactions
        .where((tx) {
          final amount = (tx['amount'] as num).toDouble();
          return amount >= 100;
        })
        .take(10)
        .toList();

    final isTriggered = _actionDeckOverscroll.abs() > _dismissThreshold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 1. DELETE ALL INDICATOR (Behind list)
            Positioned(
              left: 24,
              child: Opacity(
                opacity: (_actionDeckOverscroll.abs() / _dismissThreshold)
                    .clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: isTriggered
                                ? theme.colorScheme.error
                                : theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            boxShadow: isTriggered
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.error.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            color: isTriggered
                                ? theme.colorScheme.onError
                                : theme.colorScheme.onSurfaceVariant,
                            size: 28,
                          ),
                        )
                        .animate(target: isTriggered ? 1 : 0)
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.15, 1.15),
                          duration: 200.ms,
                        ),
                    const SizedBox(height: 8),
                    Text(
                      "Ignore All",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isTriggered
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. SCROLLABLE CONTENT
            Listener(
              onPointerUp: (_) async {
                if (isTriggered) {
                  final confirmed = await ModernAlertDialog.show<bool>(
                    context,
                    title: "Ignore All?",
                    description:
                        "This will clear all pending notifications from your action deck.",
                    icon: HugeIcons.strokeRoundedDelete02,
                    iconColor: theme.colorScheme.error,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        child: const Text("Ignore All"),
                      ),
                    ],
                  );

                  if (confirmed == true) {
                    widget.onIgnoreAll();
                    HapticFeedback.heavyImpact();
                  }

                  setState(() {
                    _isDismissTriggered = false;
                    _actionDeckOverscroll = 0;
                  });
                }
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    // Detect left-side overscroll
                    if (notification.metrics.pixels < 0) {
                      final overscroll = notification.metrics.pixels;
                      setState(() => _actionDeckOverscroll = overscroll);

                      if (overscroll.abs() > _dismissThreshold &&
                          !_isDismissTriggered) {
                        HapticFeedback.mediumImpact();
                        setState(() => _isDismissTriggered = true);
                      } else if (overscroll.abs() < _dismissThreshold &&
                          _isDismissTriggered) {
                        setState(() => _isDismissTriggered = false);
                      }
                    } else if (_actionDeckOverscroll != 0) {
                      setState(() => _actionDeckOverscroll = 0.0);
                    }
                  }
                  return false;
                },
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    // SMS Transactions
                    ...highValueTransactions.map((tx) {
                      final amount = (tx['amount'] as num).toDouble();
                      final rawType = tx['type'].toString().toLowerCase();
                      final isIncome =
                          rawType.contains('credit') ||
                          rawType.contains('income') ||
                          rawType.contains('deposi');

                      final date = tx['timestamp'] != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                              tx['timestamp'] as int,
                            )
                          : DateTime.now();

                      final payee = tx['payee'] ?? tx['merchant'] ?? 'Unknown';
                      final account =
                          tx['bankName'] ?? tx['accountNumber'] ?? 'SMS';

                      return _ActionCard(
                        key: ValueKey("sms_${tx.hashCode}"),
                        currencySymbol: currencySymbol,
                        title: payee,
                        subtitle: account,
                        date: date,
                        amount: amount,
                        isIncome: isIncome,
                        tag: "SMS",
                        icon: isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        baseColor: isIncome
                            ? (appColors?.income ?? Colors.green)
                            : (appColors?.expense ?? Colors.red),
                        onTap: () => widget.onPendingSmsTap(tx),
                        onDismiss: () async {
                          widget.onPendingSmsDismiss(tx);
                          return true;
                        },
                      );
                    }),

                    // Due Subscriptions
                    ...widget.dueSubscriptions.map((sub) {
                      return _ActionCard(
                        key: ValueKey("sub_${sub.hashCode}"),
                        currencySymbol: currencySymbol,
                        title: sub.subscriptionName,
                        subtitle: "Renew Subscription",
                        date: sub.dueDate,
                        amount: sub.averageAmount,
                        isIncome: false, // Subs are expenses
                        tag: "SUB",
                        icon: Icons.autorenew_rounded,
                        baseColor: theme.colorScheme.tertiary,
                        onTap: () => widget.onDueSubscriptionTap(sub),
                        onDismiss: () async {
                          widget.onDueSubscriptionDismiss(sub);
                          return true;
                        },
                      );
                    }),

                    // Show All Button
                    if (widget.pendingSmsTransactions.isNotEmpty)
                      _ShowAllCard(
                        count: widget.pendingSmsTransactions.length,
                        onTap: widget.onShowAllTap,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String currencySymbol;
  final String title;
  final String subtitle;
  final DateTime? date;
  final double amount;
  final bool isIncome;
  final String tag;
  final dynamic icon;
  final Color baseColor;
  final VoidCallback onTap;
  final Future<bool> Function() onDismiss;

  const _ActionCard({
    super.key,
    required this.currencySymbol,
    required this.title,
    required this.subtitle,
    this.date,
    required this.amount,
    required this.isIncome,
    required this.tag,
    required this.icon,
    required this.baseColor,
    required this.onTap,
    required this.onDismiss,
  });

  String get _formattedDate {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date!);
    if (diff.inHours < 24) {
      if (diff.inHours == 0) return "${diff.inMinutes}m ago";
      return "${diff.inHours}h ago";
    }
    return DateFormat('MMM d').format(date!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine signage
    // final sign = isIncome ? "+" : "-";
    final amountStr =
        "$currencySymbol${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}";

    return Dismissible(
      key: key!,
      direction: DismissDirection.up,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await ModernAlertDialog.show<bool>(
          context,
          title: "Dismiss ${tag == 'SUB' ? 'Subscription' : 'Transaction'}?",
          description: "Are you sure you want to dismiss this $title?",
          icon: HugeIcons.strokeRoundedDelete02,
          iconColor: baseColor,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text("Dismiss"),
            ),
          ],
        );

        if (confirmed == true) {
          return await onDismiss();
        }
        return false;
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: baseColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Subtle gradient background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          baseColor.withValues(alpha: 0.05),
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Tag and Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(icon, size: 16, color: baseColor),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formattedDate,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Amount (The Hero)
                      Text(
                        amountStr,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: baseColor,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Footer: Details and Action
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: baseColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: baseColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowAllCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ShowAllCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "See All",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "$count items",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
