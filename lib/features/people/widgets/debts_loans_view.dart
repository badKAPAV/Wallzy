import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/people_list_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

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
    final theme = Theme.of(context);

    final currentList = _selectedType == 'youOwe'
        ? peopleProvider.youOweList
        : peopleProvider.owesYouList;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Dashboard Pod
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _DebtDashboardPod(
              totalYouOwe: peopleProvider.totalYouOwe,
              totalOwesYou: peopleProvider.totalOwesYou,
              currencyFormat: currencyFormat,
            ),
          ),
        ),

        // 2. Segmented Toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: _SegmentedDebtToggle(
              selectedType: _selectedType,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
            ),
          ),
        ),

        // 3. List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              _selectedType == 'youOwe'
                  ? 'PEOPLE YOU OWE'
                  : 'PEOPLE WHO OWE YOU',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ),

        // 4. List (Reusing existing PeopleListView but styled if possible)
        // Since PeopleListView is external, we assume it renders list tiles.
        // If it was local, we'd wrap tiles in _Funky containers.
        if (currentList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyReportPlaceholder(
              message: "All settled up!",
              icon: HugeIcons.strokeRoundedTick02,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            sliver: PeopleListView(people: currentList),
          ),
      ],
    );
  }
}

class _DebtDashboardPod extends StatelessWidget {
  final double totalYouOwe;
  final double totalOwesYou;
  final NumberFormat currencyFormat;

  const _DebtDashboardPod({
    required this.totalYouOwe,
    required this.totalOwesYou,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final total = totalYouOwe + totalOwesYou;
    final hasData = total > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          // Chart
          SizedBox(
            height: 100,
            width: 100,
            child: hasData
                ? PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: totalYouOwe,
                          color: appColors.expense,
                          radius: 12,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: totalOwesYou,
                          color: appColors.income,
                          radius: 12,
                          showTitle: false,
                        ),
                      ],
                      sectionsSpace: 4,
                      centerSpaceRadius: 35,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 4,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 24),
          // Stats Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                  label: "You Owe",
                  amount: totalYouOwe,
                  color: appColors.expense,
                ),
                Divider(
                  height: 24,
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
                _StatRow(
                  label: "Owes You",
                  amount: totalOwesYou,
                  color: appColors.income,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _StatRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _SegmentedDebtToggle extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _SegmentedDebtToggle({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: "You Owe",
              color: appColors.expense,
              isSelected: selectedType == 'youOwe',
              onTap: () => onTypeSelected('youOwe'),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: "Owes You",
              color: appColors.income,
              isSelected: selectedType == 'owesYou',
              onTap: () => onTypeSelected('owesYou'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
