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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';
import 'package:wallzy/features/transaction/widgets/add_receipt_modal_sheet.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/screens/subscription_details_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;
  final List<String> parentTagIds;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.parentTagIds = const [],
  });

  // --- Logic Helper Methods (Unchanged) ---

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

  void _navigateToSubscriptionDetails(BuildContext context, Subscription? sub) {
    if (sub == null) return;
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final subTransactions = txProvider.transactions
        .where((tx) => tx.subscriptionId == sub.id)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailsScreen(
          subscription: sub,
          transactions: subTransactions,
        ),
      ),
    );
  }

  void _viewReceipt(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Selector<TransactionProvider, TransactionModel?>(
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

                // --- Data Parsing ---
                final isExpense = tx.type == 'expense';
                final typeColor = isExpense
                    ? (appColors.expense)
                    : (appColors.income);

                final currencyFormat = NumberFormat.currency(
                  symbol: currencySymbol,
                  decimalDigits: 2,
                );

                // Account Logic
                final account = tx.accountId != null
                    ? accountProvider.accounts.firstWhereOrNull(
                        (acc) => acc.id == tx.accountId,
                      )
                    : null;

                String paymentDisplay = tx.paymentMethod;
                String accountNameDisplay = "Unlinked";

                if (account != null) {
                  accountNameDisplay = account.bankName;
                  if (account.bankName.toLowerCase() == 'cash' &&
                      tx.paymentMethod.toLowerCase() == 'cash') {
                    paymentDisplay = 'Cash Payment';
                  }
                } else if (tx.paymentMethod.toLowerCase() == 'cash') {
                  accountNameDisplay = "Cash Wallet";
                }

                // Category/Person Logic
                String mainTitleLabel = tx.category;
                IconData mainIcon = _getIconForCategory(tx.category);

                if (tx.category.toLowerCase() == 'people' &&
                    tx.people != null &&
                    tx.people!.isNotEmpty) {
                  mainTitleLabel = tx.people!.map((p) => p.fullName).join(", ");
                  mainIcon = Icons.person_rounded;
                }

                // Date Formatting
                final dateStr = DateFormat('MMM d, yyyy').format(tx.timestamp);
                final timeStr = DateFormat('h:mm a').format(tx.timestamp);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                      child: Column(
                        children: [
                          // --- ICON ---
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(mainIcon, size: 32, color: typeColor),
                          ),
                          const SizedBox(height: 24),

                          // --- AMOUNT ---
                          Text(
                            currencyFormat.format(tx.amount),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // --- CATEGORY / PERSON NAME ---
                          Text(
                            mainTitleLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),

                          // --- DATE & TIME ---
                          Text(
                            "$dateStr  •  $timeStr",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- CHIPS ROW (Unchanged logic) ---
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // Expense/Income
                              _StatusBadge(
                                label: isExpense ? "Expense" : "Income",
                                color: colorScheme.onSurfaceVariant,
                                bgColor: colorScheme.surfaceContainerHighest,
                                icon: isExpense
                                    ? HugeIcons.strokeRoundedArrowUpRight01
                                    : HugeIcons.strokeRoundedArrowDownRight01,
                              ),

                              // Credit
                              if ((tx.isCredit ?? false) ||
                                  tx.purchaseType == 'credit')
                                _StatusBadge(
                                  label: "Credit",
                                  color: colorScheme.tertiary,
                                ),

                              // Subscription
                              if (tx.subscriptionId != null)
                                Consumer<SubscriptionProvider>(
                                  builder: (context, subProvider, _) {
                                    final sub = subProvider.subscriptions
                                        .firstWhereOrNull(
                                          (s) => s.id == tx.subscriptionId,
                                        );
                                    return InkWell(
                                      onTap: () =>
                                          _navigateToSubscriptionDetails(
                                            context,
                                            sub,
                                          ),
                                      child: _StatusBadge(
                                        label: sub != null
                                            ? sub.name
                                            : "Subscription",
                                        color: Colors.purple,
                                        icon: Icons.autorenew_rounded,
                                      ),
                                    );
                                  },
                                ),

                              // Tags (Folders)
                              if (tx.tags != null && tx.tags!.isNotEmpty)
                                ...tx.tags!.map((tag) {
                                  final colorVal =
                                      (tag is! String && tag.color != null)
                                      ? tag.color
                                      : null;
                                  final tagName = tag.name;

                                  final color = colorVal != null
                                      ? Color(colorVal)
                                      : colorScheme.primary;

                                  return InkWell(
                                    onTap: () =>
                                        _navigateToTagDetails(context, tag),
                                    borderRadius: BorderRadius.circular(20),
                                    child: _StatusBadge(
                                      label: tagName,
                                      color: color,
                                      icon: HugeIcons.strokeRoundedFolder02,
                                    ),
                                  );
                                }),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // --- ACCOUNT & PAYMENT (Slim Row) ---
                          _SlimInfoRow(
                            icon: HugeIcons.strokeRoundedWallet03,
                            title: accountNameDisplay,
                            subtitle: paymentDisplay,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),

                          // --- FOLDER & RECEIPT LOGIC ---
                          Builder(
                            builder: (context) {
                              final hasTags =
                                  tx.tags != null && tx.tags!.isNotEmpty;

                              // Receipt Widget
                              Widget receiptWidget;
                              if (tx.receiptUrl != null) {
                                // View Receipt
                                receiptWidget = _ActionTile(
                                  icon: HugeIcons.strokeRoundedInvoice01,
                                  label: "View Receipt",
                                  onTap: () =>
                                      _viewReceipt(context, tx.receiptUrl!),
                                  isDashed: false,
                                  color: colorScheme.primary,
                                );
                              } else {
                                // Add Receipt
                                receiptWidget = _ActionTile(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  label: "Add Receipt",
                                  isDashed: true,
                                  color: colorScheme.primary,
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => AddReceiptModalSheet(
                                        uploadImmediately: true,
                                        transactionId: tx.transactionId,
                                        onComplete: (url, _) async {
                                          if (url != null) {
                                            final txProvider =
                                                Provider.of<
                                                  TransactionProvider
                                                >(context, listen: false);
                                            final updatedTx = tx.copyWith(
                                              receiptUrl: () => url,
                                            );
                                            await txProvider.updateTransaction(
                                              updatedTx,
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                              }

                              if (hasTags) {
                                // Full width Receipt
                                return receiptWidget;
                              } else {
                                // Split Row: Add Folder | Receipt
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _ActionTile(
                                        icon: HugeIcons.strokeRoundedFolderAdd,
                                        label: "Add to Folder",
                                        isDashed: true,
                                        color: colorScheme.primary,
                                        onTap: () =>
                                            _showAddToFolderModal(context, tx),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: receiptWidget),
                                  ],
                                );
                              }
                            },
                          ),

                          // --- NOTE WIDGET ---
                          if (tx.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedNote01,
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

                    // 3. Bottom Actions (Edit / Delete)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: ActionBox(
                              label: "Edit",
                              icon: HugeIcons.strokeRoundedEdit02,
                              color: colorScheme.primary,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddEditTransactionScreen(
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
                              icon: HugeIcons.strokeRoundedDelete02,
                              color: colorScheme.error,
                              onTap: () => _deleteTransaction(context),
                              isDestructive: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// --- NEW UI COMPONENTS ---

class _SlimInfoRow extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SlimInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: icon is IconData
                ? Icon(icon, size: 18, color: color)
                : HugeIcon(icon: icon, color: color, size: 18, strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final bool isDashed;
  final Color color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDashed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDashed
            ? color.withOpacity(0.05)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: isDashed
            ? null
            : Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon is IconData
              ? Icon(icon, size: 18, color: color)
              : HugeIcon(icon: icon, color: color, size: 18, strokeWidth: 2),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: isDashed
          ? DashedBorder(
              color: color.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              strokeWidth: 1.5,
              dashWidth: 6,
              gap: 4,
              child: content,
            )
          : content,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final dynamic icon;
  final bool isDashed;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.bgColor,
    this.icon,
    // ignore: unused_element_parameter
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: isDashed
            ? Border.all(color: color.withOpacity(0.5))
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (icon is IconData)
              Icon(icon, color: color, size: 14)
            else
              HugeIcon(icon: icon, color: color, size: 14, strokeWidth: 2),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionBox extends StatelessWidget {
  final String label;
  final dynamic icon;
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
    final colorScheme = theme.colorScheme;

    final bgColor = isDestructive
        ? colorScheme.errorContainer.withValues(alpha: 0.15)
        : colorScheme.primaryContainer.withValues(alpha: 0.6);

    final fgColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon is IconData
                  ? Icon(icon, size: 20, color: fgColor)
                  : HugeIcon(
                      icon: icon,
                      color: fgColor,
                      size: 20,
                      strokeWidth: 2,
                    ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
