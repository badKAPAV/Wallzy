import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';
import 'package:wallzy/features/tag/screens/tag_details_screen.dart';
import 'package:wallzy/features/transaction/widgets/add_to_folder_modal_sheet.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;
  final List<String> parentTagIds;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.parentTagIds = const [],
  });

  // --- Logic Helper Methods ---

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_menu_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_filled_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'salary':
        return Icons.work_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _deleteTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: "Delete Transaction",
        description: "Are you sure you want to delete this transaction?",
        icon: HugeIcons.strokeRoundedDelete02,
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
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final txProvider = Provider.of<TransactionProvider>(
                context,
                listen: false,
              );
              txProvider.deleteTransaction(transaction.transactionId);
              if (!context.mounted) return;
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(true); // Close modal
            },
          ),
        ],
      ),
    );
  }

  void _showAddToFolderModal(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AddToFolderModalSheet(
          metaProvider: Provider.of<MetaProvider>(context, listen: false),
          txProvider: Provider.of<TransactionProvider>(context, listen: false),
          initialTags: tx.tags?.whereType<Tag>().toList() ?? [],
          scrollController: scrollController,
          onSelected: (tags) async {
            final txProvider = Provider.of<TransactionProvider>(
              context,
              listen: false,
            );
            final updatedTx = tx.copyWith(tags: tags);
            await txProvider.updateTransaction(updatedTx);
          },
        ),
      ),
    );
  }

  void _navigateToTagDetails(BuildContext context, Tag tag) {
    if (parentTagIds.contains(tag.id)) {
      Navigator.of(context).popUntil((route) {
        return route.settings.name == 'TagDetails' &&
            route.settings.arguments == tag.id;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: 'TagDetails', arguments: tag.id),
          builder: (_) => TagDetailsScreen(
            tag: tag,
            parentTagIds: [...parentTagIds, tag.id],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Wrap entire content in Selector to react to specific transaction changes
        return Selector<TransactionProvider, TransactionModel?>(
          selector: (context, provider) =>
              provider.transactions.firstWhereOrNull(
                (t) => t.transactionId == transaction.transactionId,
              ),
          shouldRebuild: (previous, next) => true,
          builder: (context, updatedTransaction, child) {
            final tx = updatedTransaction ?? transaction;

            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final appColors = theme.extension<AppColors>()!;
            final accountProvider = Provider.of<AccountProvider>(
              context,
              listen: false,
            );
            final settingsProvider = Provider.of<SettingsProvider>(context);
            final currencySymbol = settingsProvider.currencySymbol;

            // 1. Data Parsing
            final isExpense = tx.type == 'expense';
            final typeColor = isExpense
                ? (appColors.expense)
                : (appColors.income);

            final currencyFormat = NumberFormat.currency(
              symbol: currencySymbol,
              decimalDigits: 2,
            );

            // Resolve Account Name logic
            final account = tx.accountId != null
                ? accountProvider.accounts.firstWhereOrNull(
                    (acc) => acc.id == tx.accountId,
                  )
                : null;

            String paymentDisplay = tx.paymentMethod;
            if (account != null) {
              if (account.bankName.toLowerCase() == 'cash' &&
                  tx.paymentMethod.toLowerCase() == 'cash') {
                paymentDisplay = 'Cash';
              } else {
                paymentDisplay = account.bankName;
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
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

                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 2. The Hero Header (Icon + Amount + Badges)
                          _TransactionHero(
                            amount: currencyFormat.format(tx.amount),
                            categoryIcon: _getIconForCategory(tx.category),
                            typeColor: typeColor,
                            isExpense: isExpense,
                            tags: tx.tags,
                            isCredit:
                                (tx.isCredit ?? false) ||
                                tx.purchaseType == 'credit',
                            onAddFolder: () =>
                                _showAddToFolderModal(context, tx),
                            onTagTap: (tag) =>
                                _navigateToTagDetails(context, tag),
                          ),

                          const SizedBox(height: 24),

                          // 3. Action Row (Edit / Delete)
                          Row(
                            children: [
                              Expanded(
                                child: ActionBox(
                                  label: "Edit",
                                  icon: Icons.edit_rounded,
                                  color: colorScheme.primary,
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddEditTransactionScreen(
                                              transaction: tx,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActionBox(
                                  label: "Delete",
                                  icon: Icons.delete_outline_rounded,
                                  color: colorScheme.error,
                                  onTap: () => _deleteTransaction(context),
                                  isDestructive: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // 4. Details Grid
                          Text(
                            "Details",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Row 1: Date & Time
                          Row(
                            children: [
                              Expanded(
                                child: DataTile(
                                  label: "Date",
                                  value: DateFormat(
                                    'MMM d, yyyy',
                                  ).format(tx.timestamp),
                                  icon: Icons.calendar_today_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DataTile(
                                  label: "Time",
                                  value: DateFormat(
                                    'h:mm a',
                                  ).format(tx.timestamp),
                                  icon: Icons.access_time_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 2: Account & Category
                          Row(
                            children: [
                              Expanded(
                                child: DataTile(
                                  label: "Wallet / Bank",
                                  value: paymentDisplay,
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DataTile(
                                  label: "Category",
                                  value: tx.category,
                                  icon: Icons.category_rounded,
                                ),
                              ),
                            ],
                          ),

                          // Conditional: Add to Folder (If tags empty)
                          if (tx.tags == null || tx.tags!.isEmpty) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _showAddToFolderModal(context, tx),
                              borderRadius: BorderRadius.circular(20),
                              child: DataTile(
                                label: "Folder",
                                value: "Add to Folder",
                                icon: Icons.create_new_folder_outlined,
                                isAction: true,
                              ),
                            ),
                          ],

                          // Conditional: People (Shows all people joined by comma)
                          if (tx.people?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            DataTile(
                              label: "With",
                              value: tx.people!
                                  .map((p) => p.fullName)
                                  .join(", "),
                              icon: Icons.people_alt_rounded,
                            ),
                          ],

                          // Conditional: Subscription (Restored frequency text)
                          if (tx.subscriptionId != null) ...[
                            const SizedBox(height: 12),
                            Consumer<SubscriptionProvider>(
                              builder: (context, subProvider, _) {
                                final sub = subProvider.subscriptions
                                    .firstWhereOrNull(
                                      (s) => s.id == tx.subscriptionId,
                                    );
                                // Restored logic to show Name + Frequency
                                final displayText = sub != null
                                    ? '${sub.name} (${sub.frequency.name})'
                                    : 'Linked Subscription';

                                return DataTile(
                                  label: "Linked Subscription",
                                  value: displayText,
                                  icon: Icons.autorenew_rounded,
                                );
                              },
                            ),
                          ],

                          // 5. Note / Description
                          if (tx.description.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.notes_rounded,
                                        size: 16,
                                        color: colorScheme.outline,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "NOTE",
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.outline,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tx.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
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
          },
        );
      },
    );
  }
}

// --- SUB-WIDGETS ---

class _TransactionHero extends StatelessWidget {
  final String amount;
  final IconData categoryIcon;
  final Color typeColor;
  final bool isExpense;
  final List<dynamic>? tags;
  final bool isCredit;
  final VoidCallback? onAddFolder;
  final Function(Tag)? onTagTap;

  const _TransactionHero({
    required this.amount,
    required this.categoryIcon,
    required this.typeColor,
    required this.isExpense,
    required this.tags,
    required this.isCredit,
    this.onAddFolder,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon Circle
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(categoryIcon, size: 36, color: typeColor),
        ),
        const SizedBox(height: 16),

        // Amount
        Text(
          amount,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        // Badges Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            // 1. Restored Income/Expense Badge
            _StatusBadge(
              label: isExpense ? "Expense" : "Income",
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              bgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: isExpense
                  ? HugeIcons.strokeRoundedArrowUpRight01
                  : HugeIcons.strokeRoundedArrowDownRight01,
            ),

            // 2. Credit Badge
            if (isCredit)
              _StatusBadge(
                label: "Credit",
                color: Theme.of(context).colorScheme.tertiary,
              ),

            // 3. Tag Badges
            if (tags != null && tags!.isNotEmpty)
              ...tags!.map((tag) {
                final colorVal = (tag is! String && tag.color != null)
                    ? tag.color
                    : null;
                final tagName = (tag is String) ? tag : tag.name;

                final color = colorVal != null
                    ? Color(colorVal)
                    : Theme.of(context).colorScheme.primary;

                return InkWell(
                  onTap: (tag is Tag && onTagTap != null)
                      ? () => onTagTap!(tag)
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: _StatusBadge(
                    label: tagName,
                    color: color,
                    icon: HugeIcons.strokeRoundedFolder02,
                  ),
                );
              }),

            // Add Folder Button (Small)
            if (onAddFolder != null && (tags == null || tags!.isEmpty))
              InkWell(
                onTap: onAddFolder,
                borderRadius: BorderRadius.circular(20),
                child: _StatusBadge(
                  label: "Add to Folder",
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.add_rounded,
                  isDashed: true,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final dynamic
  icon; // Changed to dynamic to support both IconData and HugeIcon
  final bool isDashed;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.bgColor,
    this.icon,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: isDashed
            ? Border.all(
                color: color.withOpacity(0.5),
              ) // Standard border till we need real dashed
            : Border.all(
                color: bgColor != null
                    ? Colors.transparent
                    : color.withOpacity(0.2),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (icon is IconData)
              Icon(icon, color: color, size: 14)
            else if (icon
                is List<
                  List<dynamic>
                >) // HugeIcon raw data (legacy support if strictly needed)
              HugeIcon(icon: icon, color: color, size: 14, strokeWidth: 2)
            else
              // Default fallback if possible? Or assume it's IconData now.
              // Actually HugeIcons.strokeRounded... returns List<List<dynamic>>? OR IconData?
              // Wait, HugeIcons definitions are typically static const IconData or dynamic.
              // Let's assume standard Icon usage if possible, or support both.
              // Checking usage: HugeIcons.strokeRoundedArrowUpRight01 is usually a unique type?
              // Ah, HugeIcons package uses specific types.
              // Let's rely on HugeIcon widget which takes `icon` param.
              HugeIcon(icon: icon, color: color, size: 14, strokeWidth: 2),

            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Copied ActionBox for completeness
class ActionBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const ActionBox({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isDestructive
        ? color.withOpacity(0.1)
        : theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Copied DataTile for completeness
class DataTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isCopyable;
  final bool isAction;

  const DataTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isCopyable = false,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAction
            ? colorScheme.primary.withOpacity(0.1)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: isAction
            ? Border.all(color: colorScheme.primary.withOpacity(0.3))
            : Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              if (isCopyable)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isAction ? colorScheme.primary : colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
