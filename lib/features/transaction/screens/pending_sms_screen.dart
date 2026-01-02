import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingSmsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Function(Map<String, dynamic>) onAdd;
  final Function(Map<String, dynamic>) onDismiss;

  const PendingSmsScreen({
    super.key,
    required this.transactions,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pending Transactions")),
        body: const Center(child: Text("No pending transactions found.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Pending Transactions (${transactions.length})"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tx = transactions[index];
          final amount = (tx['amount'] as num).toDouble();
          final merchant = tx['payee'] ?? tx['merchant'] ?? 'Unknown Merchant';
          // Ensure we can parse the date string or use timestamp
          DateTime date;
          if (tx['timestamp'] != null && tx['timestamp'] is int) {
            date = DateTime.fromMillisecondsSinceEpoch(tx['timestamp']);
          } else {
            date = DateTime.tryParse(tx['date'] ?? '') ?? DateTime.now();
          }

          final type = tx['type'] ?? 'expense';
          final isIncome = type == 'income';
          final color = isIncome ? Colors.green : Colors.red;
          final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

          return Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              title: Text(
                merchant,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                DateFormat('MMM d, h:mm a').format(date),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ₹ $amount',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context); // Go back to Home first? Or stay?
                // User probably wants to process it.
                // Let's pop and then trigger the add callback.
                // Or better, just trigger callback and let it handle navigation.
                onAdd(tx);
              },
            ),
          );
        },
      ),
    );
  }
}
