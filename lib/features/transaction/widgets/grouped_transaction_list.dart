import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';

class GroupedTransactionList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onTap;
  final bool useSliver;

  const GroupedTransactionList({
    super.key,
    required this.transactions,
    required this.onTap,
    this.useSliver = true,
  });

  Map<String, List<TransactionModel>> _groupTransactionsByDate() {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      String key;
      if (txDate.isAtSameMomentAs(today)) {
        key = 'Today';
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMM d, yyyy').format(txDate);
      }
      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      if (useSliver) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return const SizedBox.shrink();
    }

    final groupedTransactions = _groupTransactionsByDate();

    if (useSliver) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGroup(context, index, groupedTransactions),
          childCount: groupedTransactions.length,
        ),
      );
    } else {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: groupedTransactions.length,
        itemBuilder: (context, index) =>
            _buildGroup(context, index, groupedTransactions),
      );
    }
  }

  Widget _buildGroup(
    BuildContext context,
    int index,
    Map<String, List<TransactionModel>> groupedTransactions,
  ) {
    final dateKey = groupedTransactions.keys.elementAt(index);
    final transactionsForDate = groupedTransactions[dateKey]!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            dateKey.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        ...transactionsForDate.map(
          (tx) => TransactionListItem(transaction: tx, onTap: () => onTap(tx)),
        ),
      ],
    );
  }
}
