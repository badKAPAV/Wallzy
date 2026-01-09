import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

class TagDetailsScreen extends StatelessWidget {
  final Tag tag;

  const TagDetailsScreen({super.key, required this.tag});

  Color _getTagColor(Tag tag, BuildContext context) {
    if (tag.color != null) return Color(tag.color!);
    return Theme.of(context).colorScheme.primary;
  }

  void _showEditTagDialog(BuildContext context, Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];
    int? selectedColor = tag.color;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Edit Folder"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Folder Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Select Color"),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () => setState(() => selectedColor = null),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                          color: Colors.transparent,
                        ),
                        child: selectedColor == null
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                    ),
                    ...colors.map(
                      (c) => InkWell(
                        onTap: () => setState(() => selectedColor = c.value),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selectedColor == c.value
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                          child: selectedColor == c.value
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    final updatedTag = Tag(
                      id: tag.id,
                      name: newName,
                      color: selectedColor,
                    );
                    final metaProvider = Provider.of<MetaProvider>(
                      context,
                      listen: false,
                    );
                    await metaProvider.updateTag(updatedTag);
                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Tag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete \"${tag.name}\"?"),
        content: Text(
          "Are you sure you want to delete \"${tag.name}\"? This will not delete transactions in this folder, but they will no longer be grouped by it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final metaProvider = Provider.of<MetaProvider>(
                context,
                listen: false,
              );
              await metaProvider.deleteTag(tag.id);
              if (context.mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back from details screen
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to MetaProvider to get the latest tag update (e.g. after edit)
    final metaProvider = Provider.of<MetaProvider>(context);
    // Find the latest version of this tag, fallback to the passed tag if not found (e.g. deleted)
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

          // Map to track category usage with this tag
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

          // Prepare Chart Data (Sort by value desc)
          final sortedCategories = categoryMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final settingsProvider = Provider.of<SettingsProvider>(context);
          final currencySymbol = settingsProvider.currencySymbol;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.medium(
                expandedHeight: 200,
                centerTitle: false,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                title: Text(currentTag.name),
                actions: [
                  IconButton.filledTonal(
                    tooltip: 'Edit Folder',
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    onPressed: () => _showEditTagDialog(context, currentTag),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit03,
                      size: 20,
                      strokeWidth: 2,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Delete Folder',
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    onPressed: () =>
                        _showDeleteConfirmation(context, currentTag),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
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
                                balance >= 0 ? "Positive Flow" : "Net Outflow",
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

              // const SliverToBoxAdapter(child: SizedBox(height: 16)),

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

              // 3. Donut Category Distribution (If expenses exist)
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
                      builder: (context) => DraggableScrollableSheet(
                        initialChildSize: 0.72,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, controller) =>
                            TransactionDetailScreen(transaction: tx),
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

// --- WIDGETS ---

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

// --- CATEGORY DONUT POD ---

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
    // Generate harmonious colors: Split Complementary or Analogous
    final hsl = HSLColor.fromColor(baseColor);
    // Shift hue for each subsequent category to create separation
    // We alternate shifts to avoid simple rainbow effects
    final double hueShift = 30.0 * (index + 1);
    return hsl.withHue((hsl.hue + hueShift) % 360).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(symbol: currencySymbol);
    // Top 4 categories for the chart + 'Others'
    final displayCategories = categories.take(4).toList();
    final otherTotal = categories
        .skip(4)
        .fold(0.0, (sum, item) => sum + item.value);

    // Prepare data for painter
    final List<double> values = [
      ...displayCategories.map((e) => e.value),
      if (otherTotal > 0) otherTotal,
    ];
    final List<Color> colors = List.generate(
      values.length,
      (i) => _getCategoryColor(i, accentColor),
    );

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
              // 1. DONUT CHART
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    values: values,
                    colors: colors,
                    total: total,
                    width: 18,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${((values.first / total) * 100).toStringAsFixed(0)}%",
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
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // 2. LEGEND
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    displayCategories.length + (otherTotal > 0 ? 1 : 0),
                    (index) {
                      final bool isOther = index >= displayCategories.length;
                      final label = isOther
                          ? "Others"
                          : displayCategories[index].key;
                      final value = isOther
                          ? otherTotal
                          : displayCategories[index].value;
                      final color = colors[index];

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
                    },
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

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double total;
  final double width;

  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.total,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - width) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -3.14159 / 2; // Start from top (-90 deg)

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      // Draw arcs with slight gaps if multiple segments
      final gap = values.length > 1 ? 0.05 : 0.0;
      canvas.drawArc(rect, startAngle + gap, sweepAngle - gap, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
