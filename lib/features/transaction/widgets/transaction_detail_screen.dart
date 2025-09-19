import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  // Helper to get a relevant icon for the category
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
      default:
        return Icons.category_rounded;
    }
  }

  void _deleteTransaction(BuildContext context) {
    // Get colorScheme before the dialog to use it inside
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: const Text('Delete Transaction'),
        content: const Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            // Use the theme's error color for destructive actions
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
            onPressed: () async {
              final txProvider =
                  Provider.of<TransactionProvider>(context, listen: false);
              await txProvider.deleteTransaction(transaction.transactionId);
              if (!context.mounted) return;
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(true); // Close bottom sheet
            },
          ),
        ],
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTransactionScreen(
        isExpense: transaction.type == 'expense',
        transaction: transaction,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final isExpense = transaction.type == 'expense';
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final amountColor = isExpense ? appColors.expense : appColors.income;
    final descriptionTitle = transaction.description.isNotEmpty
        ? transaction.description
        : transaction.category;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface, // Use a base surface color
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main Info Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getIconForCategory(transaction.category),
                      color: colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      transaction.category,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currencyFormat.format(transaction.amount),
                  style: textTheme.headlineLarge?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descriptionTitle,
                  style: textTheme.titleMedium
                      ?.copyWith(color: colorScheme.onPrimaryContainer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details Section
          _DetailTile(
            icon: Icons.calendar_today_rounded,
            title: 'Date & Time',
            value:
                DateFormat('d MMM y, hh:mm a').format(transaction.timestamp),
            iconColor: colorScheme.secondary,
          ),
          _DetailTile(
            icon: Icons.wallet_rounded,
            title: 'Payment Method',
            value: transaction.paymentMethod,
            iconColor: colorScheme.tertiary,
          ),
          if (transaction.people?.isNotEmpty == true)
            _DetailTile(
              icon: Icons.person_rounded,
              title: 'Person',
              value: transaction.people!.first.name,
              iconColor: colorScheme.primary,
            ),
          if (transaction.tags?.isNotEmpty == true)
            _DetailTile(
              icon: Icons.label_rounded,
              title: 'Tags',
              value: transaction.tags!.map((t) => t.name).join(', '),
              iconColor: colorScheme.secondary,
            ),

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                  onPressed: () => _deleteTransaction(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                  onPressed: () => _editTransaction(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A new, styled widget for displaying detail rows.
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}