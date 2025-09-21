import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

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
    final isExpense = transaction.type == 'expense';
    final isCreditPurchase = transaction.purchaseType == 'credit';
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    final Color amountColor;
    final String amountString;

    if (isCreditPurchase) {
      // Credit purchases are neutral, they don't affect global balance
      amountColor = Theme.of(context).colorScheme.onSurfaceVariant;
      amountString = currencyFormat.format(transaction.amount);
    } else {
      amountColor = isExpense ? Colors.redAccent : Colors.green;
      amountString = '${isExpense ? '-' : '+'} ${currencyFormat.format(transaction.amount)}';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(40),
              child: Icon(_getIconForCategory(transaction.category), color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty ? transaction.description : transaction.category.toLowerCase() == 'people' ? transaction.people!.first.name : transaction.category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMd().format(transaction.timestamp), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                ],
              ),
            ),
            Text(amountString, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
