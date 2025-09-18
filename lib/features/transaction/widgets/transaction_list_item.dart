import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionListItem({super.key, required this.transaction, this.onTap});

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_menu;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'transport':
        return Icons.directions_car_filled_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'salary':
        return Icons.work_outline;
      case 'people':
        return Icons.people_outline;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    final isExpense = transaction.type == 'expense';
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final amountColor = isExpense ? Colors.redAccent : Colors.greenAccent;
    final amountString =
        '${isExpense ? '-' : '+'} ${currencyFormat.format(transaction.amount)}';

    return Hero(
      // Add Hero widget for shared element transitions
      tag: 'transaction_card_${transaction.transactionId}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    _getIconForCategory(transaction.category),
                    color: colorScheme.primary, 
                    size: 20
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        String title = transaction.description;
                        if (title.isEmpty) {
                          if (transaction.category.toLowerCase() == 'people' &&
                              transaction.people?.isNotEmpty == true) {
                            title = transaction.people!.first.name;
                          } else {
                            title = transaction.category;
                          }
                        }
                        return Text(
                          title,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMM y, hh:mm a').format(transaction.timestamp),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  amountString,
                  style: textTheme.titleMedium?.copyWith(color: amountColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
