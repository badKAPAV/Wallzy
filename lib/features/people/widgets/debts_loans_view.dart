import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/people_list_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';

class DebtsLoansView extends StatefulWidget {
  const DebtsLoansView({super.key});

  @override
  State<DebtsLoansView> createState() => _DebtsLoansViewState();
}

class _DebtsLoansViewState extends State<DebtsLoansView> {
  String _selectedType = 'youOwe';

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final peopleProvider = Provider.of<PeopleProvider>(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
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

        // 2. Segmented Toggle (Now with Sliding Animation)
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

        // 4. List
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
            sliver: PeopleListView(
              people: currentList,
              onDismissed: (person) {
                final newPerson = _selectedType == 'youOwe'
                    ? person.copyWith(youOwe: 0)
                    : person.copyWith(owesYou: 0);

                peopleProvider.updatePerson(newPerson);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    content: const Text('Debt cleared'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        peopleProvider.updatePerson(person);
                      },
                    ),
                  ),
                );
              },
            ),
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
                ? LedgrPieChart(
                    thickness: 12,
                    gap: 24,
                    sections: [
                      if (totalYouOwe > 0)
                        PieData(value: totalYouOwe, color: appColors.expense),
                      if (totalOwesYou > 0)
                        PieData(value: totalOwesYou, color: appColors.income),
                    ],
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
                  color: theme.colorScheme.outlineVariant.withAlpha(128),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
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

    // Determine current active color for text
    final isYouOwe = selectedType == 'youOwe';

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 1. The Sliding White Background
          AnimatedAlign(
            alignment: isYouOwe ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. The Text Labels (Sitting on top)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTypeSelected('youOwe'),
                  child: Center(
                    child: Text(
                      'You Owe',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isYouOwe
                            ? appColors.expense
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTypeSelected('owesYou'),
                  child: Center(
                    child: Text(
                      'Owes You',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: !isYouOwe
                            ? appColors.income
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
