import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  void _deleteTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Transaction'),
        content: const Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              final txProvider =
                  Provider.of<TransactionProvider>(context, listen: false);
              await txProvider.deleteTransaction(transaction.transactionId);
              if (!context.mounted) return;
              // Close dialog
              Navigator.of(ctx).pop();
              // Close bottom sheet and signal success
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    // The edit screen will pop all the way back to home after saving.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTransactionScreen(
        isExpense: transaction.type == 'expense',
        transaction: transaction,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final amountColor = isExpense ? Colors.redAccent : Colors.greenAccent;

    return PopScope(
      canPop: true,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              transaction.description.isNotEmpty
                  ? transaction.description
                  : transaction.category,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(transaction.amount),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: amountColor),
            ),
            const SizedBox(height: 24),
            _DetailRow(
                icon: Icons.category_outlined,
                title: 'Category',
                value: transaction.category),
            _DetailRow(
                icon: Icons.calendar_today_outlined,
                title: 'Date',
                value: DateFormat('d MMM y, hh:mm a').format(transaction.timestamp)),
            _DetailRow(
                icon: Icons.payment_outlined,
                title: 'Payment Method',
                value: transaction.paymentMethod),
            if (transaction.people?.isNotEmpty == true)
              _DetailRow(
                  icon: Icons.person_outline,
                  title: 'Person',
                  value: transaction.people!.first.name),
            if (transaction.tags?.isNotEmpty == true)
              _DetailRow(
                  icon: Icons.tag,
                  title: 'Tags',
                  value: transaction.tags!.map((t) => t.name).join(', ')),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () => _deleteTransaction(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: () => _editTransaction(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
          Text('$title:', style: const TextStyle(color: Colors.white54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}