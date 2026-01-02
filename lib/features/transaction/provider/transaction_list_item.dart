import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/core/themes/theme.dart';
import '../models/transaction.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionListItem({super.key, required this.transaction, this.onTap});

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.fastfood_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'salary':
        return Icons.work_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors =
        Theme.of(context).extension<AppColors>() ??
        const AppColors(income: Colors.green, expense: Colors.red);
    final isExpense = transaction.type == 'expense';
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final amountColor = isExpense
        ? Theme.of(context).colorScheme.onSurface
        : appColors.income;
    final amountString =
        '${isExpense ? '-' : '+'}${currencyFormat.format(transaction.amount)}';

    // Logic for Credit Tag
    final bool showCreditTag =
        (transaction.isCredit == true ||
            transaction.purchaseType == 'credit') ||
        (transaction.category.toLowerCase() == 'people' &&
            transaction.people?.isNotEmpty == true);

    // Logic for Title
    final String title =
        (transaction.category.toLowerCase() == 'people' &&
            transaction.people?.isNotEmpty == true)
        ? transaction.people!.first.fullName
        : (transaction.description.isNotEmpty
              ? transaction.description
              : transaction.category);

    IconData icon = isExpense
        ? Icons.arrow_outward_rounded
        : Icons.arrow_downward_rounded;
    if (transaction.category.toLowerCase().contains('food')) {
      icon = Icons.fastfood_rounded;
    } else if (transaction.category.toLowerCase().contains('shop')) {
      icon = Icons.shopping_bag_rounded;
    } else {
      icon = _getIconForCategory(transaction.category);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isExpense ? appColors.expense : appColors.income)
                        .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isExpense ? appColors.expense : appColors.income,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Center Column (Title + Date/Time + Credit Tag)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormat(
                              'MMM d, y • h:mm a',
                            ).format(transaction.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (showCreditTag) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CREDIT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Right Column (Amount + Payment Method)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountString,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: amountColor,
                      ),
                    ),
                    if (transaction.paymentMethod.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.paymentMethod,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }
}
