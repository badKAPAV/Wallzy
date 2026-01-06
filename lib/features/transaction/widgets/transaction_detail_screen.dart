import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Assuming you added this for the home screen
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  // --- Logic Methods (Kept Intact) ---

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
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: const Text('Shred Receipt?'),
        content: const Text(
          'This will permanently delete this transaction record.',
        ),
        actions: [
          TextButton(
            child: const Text('Keep it'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('Shred'),
            onPressed: () async {
              final txProvider = Provider.of<TransactionProvider>(
                context,
                listen: false,
              );
              txProvider.deleteTransaction(transaction.transactionId);
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(transaction: transaction),
      ),
    );
  }

  // --- Reimagined UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );

    // Data Prep
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? appColors.expense : appColors.income;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    // Resolve Account Name
    final account = transaction.accountId != null
        ? accountProvider.accounts
              .where((acc) => acc.id == transaction.accountId)
              .firstOrNull
        : null;

    String paymentDisplay = transaction.paymentMethod;
    if (account != null) {
      if (account.bankName.toLowerCase() == 'cash' &&
          transaction.paymentMethod.toLowerCase() == 'cash') {
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
          // 1. Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withAlpha(128),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // 2. The Receipt Card
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  // Hero Section (Icon + Amount)
                  _buildHeroSection(
                    context,
                    isExpense,
                    amountColor,
                    currencyFormat,
                  ),

                  const SizedBox(height: 32),

                  // Dashed Line Separator
                  _buildDashedDivider(context),

                  const SizedBox(height: 32),

                  // Data Grid
                  _buildInfoGrid(context, paymentDisplay),

                  // Description (if exists)
                  if (transaction.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildDescriptionBox(context),
                  ],
                ],
              ),
            ),
          ),

          // 3. Action Footer
          _buildActionFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    bool isExpense,
    Color color,
    NumberFormat formatter,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconForCategory(transaction.category),
            size: 32,
            color: color,
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(
          formatter.format(transaction.amount),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -1,
          ),
        ).animate().fadeIn().slideY(begin: 0.3, end: 0),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isExpense ? "Expense" : "Income",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            if ((transaction.isCredit != null && transaction.isCredit!) ||
                transaction.purchaseType == 'credit')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Credit',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            if (transaction.tags?.isNotEmpty == true)
              ...transaction.tags!.map((tag) {
                final color = tag.color != null
                    ? Color(tag.color!)
                    : Theme.of(context).colorScheme.primaryFixed;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context, String accountName) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: "Date",
                value: DateFormat('MMM d, y').format(transaction.timestamp),
                icon: Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                label: "Time",
                value: DateFormat('h:mm a').format(transaction.timestamp),
                icon: Icons.access_time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: "Category",
                value: transaction.category,
                icon: Icons.category_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                label: "Via",
                value: accountName,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        if (transaction.people?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _InfoTile(
            label: "With",
            value: transaction.people!.first.fullName,
            icon: Icons.people_outline,
            isFullWidth: true,
          ),
        ],
        if (transaction.subscriptionId != null) ...[
          const SizedBox(height: 16),
          Consumer<SubscriptionProvider>(
            builder: (context, subProvider, _) {
              final sub = subProvider.subscriptions
                  .where((s) => s.id == transaction.subscriptionId)
                  .firstOrNull;
              return _InfoTile(
                label: "Subscription",
                value: sub != null
                    ? '${sub.name} (${sub.frequency.name})'
                    : 'Linked Subscription',
                icon: Icons.autorenew,
                isFullWidth: true,
              );
            },
          ),
        ],
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildDescriptionBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NOTE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            transaction.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 8.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
          ),
        ),
      ),
      child: Row(
        children: [
          // Delete Button (Icon only style)
          InkWell(
            onTap: () => _deleteTransaction(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withAlpha(128),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Edit Button (Expanded Pill)
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _editTransaction(context),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text("Edit Details"),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Micro Widget for the Grid ---

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isFullWidth;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withAlpha(179),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
