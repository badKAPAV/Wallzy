import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';
import 'package:wallzy/core/themes/theme.dart';

class PeopleListView extends StatelessWidget {
  final List<Person> people;

  const PeopleListView({super.key, required this.people});

  void _recordPayment(BuildContext context, Person person, bool isSettlingUp) {
    final isOwedToYou = person.owesYou > person.youOwe;
    final balance = isOwedToYou ? person.owesYou : person.youOwe;

    // If you owe them, you are making an EXPENSE transaction to pay them back.
    // If they owe you, you are receiving an INCOME transaction from them.
    final transactionMode = isOwedToYou ? TransactionMode.income : TransactionMode.expense;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(
          initialMode: transactionMode,
          initialAmount: isSettlingUp ? balance.toStringAsFixed(2) : null,
          initialCategory: 'People',
          initialPerson: person,
        ),
      ),
    );
  }

  void _showSettleUpOptions(BuildContext context, Person person) {
    // For now, this is a placeholder. A modal bottom sheet could be shown here.
    _recordPayment(context, person, true);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    return SliverList.builder(
      itemBuilder: (context, index) {
        final person = people[index];
        final owesYou = person.owesYou;
        final youOwe = person.youOwe;
        final isOwedToYou = owesYou > youOwe;
        final balance = isOwedToYou ? owesYou : youOwe;
        final icon = isOwedToYou ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
        final color = isOwedToYou ? appColors.income : appColors.expense;

        // Don't show people with a zero balance in the debts/loans view.
        if (balance == 0) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          color: colorScheme.surface.withAlpha(200),
          child: InkWell(
            onTap: () {
              _showSettleUpOptions(context, person);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    foregroundColor: color,
                    child: Text(person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : '?'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.fullName, style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          isOwedToYou ? 'Owes you' : 'You owe them',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(balance),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        icon,
                        color: color,
                        size: 16,
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      itemCount: people.length,
    );
  }
}