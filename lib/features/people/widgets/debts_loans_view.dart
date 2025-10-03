import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/people_list_view.dart';

class DebtsLoansView extends StatefulWidget {
  const DebtsLoansView({super.key});

  @override
  State<DebtsLoansView> createState() => _DebtsLoansViewState();
}

class _DebtsLoansViewState extends State<DebtsLoansView> {
  String _selectedType = 'youOwe';

  @override
  Widget build(BuildContext context) {
    final peopleProvider = Provider.of<PeopleProvider>(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final currentList = _selectedType == 'youOwe'
        ? peopleProvider.youOweList
        : peopleProvider.owesYouList;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryCard(
            totalYouOwe: peopleProvider.totalYouOwe,
            totalOwesYou: peopleProvider.totalOwesYou,
            currencyFormat: currencyFormat,
            selectedType: _selectedType,
            onTypeSelected: (type) {
              setState(() {
                _selectedType = type;
              });
            },
          ),
        ),
        currentList.isEmpty
            ? const SliverFillRemaining(
                child: Center(child: Text('No debts or loans found.')))
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                sliver: PeopleListView(people: currentList),
              ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalYouOwe;
  final double totalOwesYou;
  final NumberFormat currencyFormat;
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _SummaryCard({
    required this.totalYouOwe,
    required this.totalOwesYou,
    required this.currencyFormat,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final total = totalYouOwe + totalOwesYou;
    final hasData = total > 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: hasData
                  ? PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: totalYouOwe,
                            color: appColors.expense,
                            title: '',
                            radius: 25,
                          ),
                          PieChartSectionData(
                            value: totalOwesYou,
                            color: appColors.income,
                            title: '',
                            radius: 25,
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                      ),
                    )
                  : const Center(child: Text("No debts or loans tracked.")),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'You Owe',
                    amount: totalYouOwe,
                    color: appColors.expense,
                    isSelected: selectedType == 'youOwe',
                    onTap: () => onTypeSelected('youOwe'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TypeButton(
                    label: 'Owes You',
                    amount: totalOwesYou,
                    color: appColors.income,
                    isSelected: selectedType == 'owesYou',
                    onTap: () => onTypeSelected('owesYou'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.amount,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: isSelected ? color.withOpacity(0.1) : null,
        side: BorderSide(color: isSelected ? color : theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(currencyFormat.format(amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}