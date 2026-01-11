import 'package:flutter/material.dart';
import 'package:wallzy/features/dashboard/widgets/home_empty_state.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';

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
          useSliver:
              false, // Not using sliver inside this widget, but maybe parent wants it?
          // The parent HomeScreen used SliverChildListDelegate or GroupedTransactionList with `useSliver: true` because it was inside CustomScrollView.
          // If we put this widget inside SliverToBoxAdapter, we should use `useSliver: false`.
          // If we put this widget directly in the list of slivers, we can't easily because it combines a header (Box) and a List (Sliver).
          // Best approach: This widget returns a Column, so it must be wrapped in SliverToBoxAdapter in the parent.
          // Therefore `GroupedTransactionList` should NOT use sliver here, but standard ListView or Column.
          // `GroupedTransactionList` implementation usually supports shrinkWrap/physics if not sliver.
        ),
      ],
    );
  }
}
