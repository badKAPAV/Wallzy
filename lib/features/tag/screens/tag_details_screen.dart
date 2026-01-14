import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/pie_chart/pie_chart_widget.dart';
import 'package:wallzy/common/pie_chart/pie_model.dart';

import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/tag/widgets/tag_info_modal_sheet.dart';
import 'package:wallzy/features/tag/widgets/event_mode_settings_card.dart';
import 'package:wallzy/features/tag/widgets/tag_budget_card.dart';
import 'package:wallzy/features/tag/widgets/add_edit_folder_budget_modal_sheet.dart';

class TagDetailsScreen extends StatelessWidget {
  final Tag tag;
  final List<String> parentTagIds;

  const TagDetailsScreen({
    super.key,
    required this.tag,
    this.parentTagIds = const [],
  });

  Color _getTagColor(Tag tag, BuildContext context) {
    if (tag.color != null) return Color(tag.color!);
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to MetaProvider to get the latest tag update
    final metaProvider = Provider.of<MetaProvider>(context);
    final currentTag = metaProvider.tags.firstWhere(
      (t) => t.id == tag.id,
      orElse: () => tag,
    );

    final theme = Theme.of(context);
    final tagColor = _getTagColor(currentTag, context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          // 1. Filter Data
          final transactions = provider.transactions
              .where(
                (tx) => tx.tags?.any((t) => t.id == currentTag.id) ?? false,
              )
              .toList();

          // 2. Calculate Deep Metrics
          double totalIncome = 0;
          double totalExpense = 0;
          int expenseCount = 0;

          final Map<String, double> categoryMap = {};

          for (var tx in transactions) {
            if (tx.type == 'income') {
              totalIncome += tx.amount;
            } else if (tx.type == 'expense') {
              totalExpense += tx.amount;
              expenseCount++;
              categoryMap.update(
                tx.category,
                (val) => val + tx.amount,
                ifAbsent: () => tx.amount,
              );
            }
          }

          final balance = totalIncome - totalExpense;
          final averageExpense = expenseCount > 0
              ? totalExpense / expenseCount
              : 0.0;

          // Prepare Chart Data
          final sortedCategories = categoryMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final settingsProvider = Provider.of<SettingsProvider>(context);
          final currencySymbol = settingsProvider.currencySymbol;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.medium(
                // ... [Same AppBar configuration as before] ...
                expandedHeight: 230,
                centerTitle: false,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                title: Text(currentTag.name),
                actions: [
                  IconButton.filledTonal(
                    tooltip: 'Folder Info',
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => TagInfoModalSheet(
                          tag: currentTag,
                          passedContext: context,
                        ),
                      );
                    },
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      size: 20,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: theme.scaffoldBackgroundColor),
                      Positioned(
                        top: -300,
                        right: -100,
                        left: -100,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                          child: SvgPicture.asset(
                            'assets/vectors/tag_gradient_vector.svg',
                            width: 500,
                            height: 500,
                            colorFilter: ColorFilter.mode(
                              tagColor.withAlpha(100),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 100,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Net Impact",
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(
                                symbol: currencySymbol,
                                decimalDigits: 0,
                              ).format(balance.abs()),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: balance >= 0
                                    ? theme.extension<AppColors>()!.income
                                    : theme.extension<AppColors>()!.expense,
                                letterSpacing: -1,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (balance >= 0 ? Colors.green : Colors.red)
                                        .withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                balance >= 0
                                    ? "Positive Flow"
                                    : "Negative Flow",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 1.5 Event Mode Settings
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      (currentTag.tagBudget != null &&
                              currentTag.tagBudget! > 0)
                          ? TagBudgetCard(tag: currentTag)
                          : _SetBudgetPrompt(tag: currentTag),
                      // Margin handled by card itself? It has vertical margin 8.
                      // Let's add slight spacing if budget card is visible (it shrinks if no budget)
                      // Ideally, the card handles its own visibility.
                      // But if it's visible, we might want spacing between it and EventMode.
                      // The Card has margin vertical 8.
                      EventModeSettingsCard(tag: currentTag),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 2. Analytics Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _InfoCard(
                              label: "Total Income",
                              value: totalIncome,
                              color: theme.extension<AppColors>()!.income,
                              icon: Icons.arrow_downward_rounded,
                            ),
                            const SizedBox(height: 12),
                            _InfoCard(
                              label: "Total Expense",
                              value: totalExpense,
                              color: theme.extension<AppColors>()!.expense,
                              icon: Icons.arrow_upward_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _MetaCard(
                              label: "Usage Count",
                              value: "${transactions.length}",
                              icon: Icons.tag_rounded,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 12),
                            _MetaCard(
                              label: "Avg. Spend",
                              value: NumberFormat.compactCurrency(
                                symbol: currencySymbol,
                              ).format(averageExpense),
                              icon: Icons.functions_rounded,
                              color: Colors.orangeAccent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Donut Category Distribution (Updated with LedgrPieChart)
              if (sortedCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: _CategoryDonutPod(
                      categories: sortedCategories,
                      total: totalExpense,
                      accentColor: tagColor,
                    ),
                  ),
                ),

              // 4. Transaction List Header
              if (transactions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Text(
                      "HISTORY",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),

              // 5. List or Empty State
              if (transactions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyReportPlaceholder(
                    message: "No transactions found in this folder yet.",
                    icon: HugeIcons.strokeRoundedFolderOpen,
                  ),
                )
              else
                GroupedTransactionList(
                  transactions: transactions,
                  useSliver: true,
                  onTap: (tx) {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TransactionDetailScreen(
                        transaction: tx,
                        parentTagIds: [...parentTagIds, currentTag.id],
                      ),
                    );
                  },
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
            ],
          );
        },
      ),
    );
  }
}

// --- UPDATED CATEGORY DONUT POD ---

class _CategoryDonutPod extends StatelessWidget {
  final List<MapEntry<String, double>> categories;
  final double total;
  final Color accentColor;

  const _CategoryDonutPod({
    required this.categories,
    required this.total,
    required this.accentColor,
  });

  Color _getCategoryColor(int index, Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final double hueShift = 30.0 * (index + 1);
    return hsl.withHue((hsl.hue + hueShift) % 360).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(symbol: currencySymbol);

    // Data Prep
    final displayCategories = categories.take(4).toList();
    final otherTotal = categories
        .skip(4)
        .fold(0.0, (sum, item) => sum + item.value);

    // Create PieData sections for LedgrPieChart
    final List<PieData> sections = [];

    // Add top categories
    for (int i = 0; i < displayCategories.length; i++) {
      sections.add(
        PieData(
          value: displayCategories[i].value,
          color: _getCategoryColor(i, accentColor),
        ),
      );
    }

    // Add 'Others' if needed
    if (otherTotal > 0) {
      sections.add(
        PieData(
          value: otherTotal,
          color: _getCategoryColor(displayCategories.length, accentColor),
        ),
      );
    }

    // Capture the top category % for display in center
    final double topPercent = sections.isNotEmpty
        ? (sections.first.value / total) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Spending Split",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${categories.length} Categories",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. LEDGR PIE CHART ENGINE 🚀
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    LedgrPieChart(
                      thickness: 18,
                      gap: 24, // Gap for visual separation
                      emptyColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(100),
                      sections: sections,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${topPercent.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          "Top",
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),

              // 2. LEGEND
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(sections.length, (index) {
                    // Logic to map PieData index back to labels
                    final bool isOther = index >= displayCategories.length;
                    final label = isOther
                        ? "Others"
                        : displayCategories[index].key;
                    final value = isOther
                        ? otherTotal
                        : displayCategories[index].value;
                    final color = sections[index].color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            currencyFormat.format(value),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(symbol: currencySymbol);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                currencyFormat.format(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetaCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color.withAlpha(179)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetBudgetPrompt extends StatelessWidget {
  final Tag tag;
  const _SetBudgetPrompt({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Open Tag Info Sheet to edit
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AddEditFolderBudgetModalSheet(tag: tag),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPieChart02,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Set a Folder Budget",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Track spending limits",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
