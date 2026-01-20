import 'package:flutter/material.dart';
import 'package:wallzy/features/dashboard/widgets/home_empty_state.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

class RecentActivityWidget extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onTap;

  const RecentActivityWidget({
    super.key,
    required this.transactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Column(children: [SizedBox(height: 24), HomeEmptyState()]);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Activity",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllTransactionsScreen(),
                  ),
                ),
                child: const Text("View All"),
              ),
            ],
          ),
        ),
        GroupedTransactionList(
          transactions: transactions,
          onTap: onTap,
          useSliver: false,
        ),
      ],
    );
  }
}
