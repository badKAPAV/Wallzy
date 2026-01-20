import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/screens/tag_details_screen.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/features/tag/widgets/folder_warning_widget.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // --- NEW: Filter State ---
  Color? _selectedColorFilter;

  // Predefined colors for tags - now using centralized list in Tag model
  final List<Color> _tagColors = Tag.defaultTagColors;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // --- NEW: Filter Sheet Logic ---
  void _showColorFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Filter by Color",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _tagColors.length + 1, // +1 for "All/Reset"
                    itemBuilder: (context, index) {
                      // First item is the Reset/All button
                      if (index == 0) {
                        final isSelected = _selectedColorFilter == null;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColorFilter = null);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              Icons.format_color_reset_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                        );
                      }

                      final color = _tagColors[index - 1];
                      final isSelected = _selectedColorFilter == color;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedColorFilter = color);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    width: 3,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedItem: DrawerItem.folders, isRoot: false),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search folders",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text(
                "Folders",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          // --- NEW: Filter Button ---
          IconButton.filledTonal(
            tooltip: 'Filters',
            onPressed: _showColorFilterSheet,
            // Change style if filter is active
            style: IconButton.styleFrom(
              backgroundColor: _selectedColorFilter != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: _selectedColorFilter != null
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedFilterHorizontal,
              strokeWidth: 2,
              size: 20,
              color: _selectedColorFilter != null
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 0),

          // Search Button
          IconButton.filledTonal(
            tooltip: 'Search',
            onPressed: () {
              if (_isSearching) {
                _stopSearch();
              } else {
                _startSearch();
              }
            },
            icon: HugeIcon(
              icon: _isSearching
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _buildGlassFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Consumer2<MetaProvider, TransactionProvider>(
        builder: (context, metaProvider, txProvider, child) {
          final tags = metaProvider.tags;
          final transactions = txProvider.transactions;

          // 1. Process Data
          final tagStats = tags.map((tag) {
            final relevantTxs = transactions
                .where((tx) => tx.tags?.any((t) => t.id == tag.id) ?? false)
                .toList();

            double income = 0;
            double expense = 0;
            DateTime? lastUsed;

            for (var tx in relevantTxs) {
              if (tx.type == 'income')
                income += tx.amount;
              else if (tx.type == 'expense')
                expense += tx.amount;
              if (lastUsed == null || tx.timestamp.isAfter(lastUsed)) {
                lastUsed = tx.timestamp;
              }
            }

            return _TagStat(
              tag: tag,
              totalIncome: income,
              totalExpense: expense,
              lastUsed: lastUsed,
              count: relevantTxs.length,
            );
          }).toList();

          // 2. Identify "Hero" Tags
          _TagStat? mostUsed;
          _TagStat? highestSpend;
          if (tagStats.isNotEmpty) {
            final sortedByCount = List<_TagStat>.from(tagStats)
              ..sort((a, b) => b.count.compareTo(a.count));
            if (sortedByCount.isNotEmpty && sortedByCount.first.count > 0)
              mostUsed = sortedByCount.first;

            final sortedByExpense = List<_TagStat>.from(tagStats)
              ..sort((a, b) => b.totalExpense.compareTo(a.totalExpense));
            if (sortedByExpense.isNotEmpty &&
                sortedByExpense.first.totalExpense > 0)
              highestSpend = sortedByExpense.first;
          }

          // 3. Filter List
          final filteredStats = tagStats.where((s) {
            // A. Search Query Check
            final matchesSearch = s.tag.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

            // B. Color Filter Check (NEW)
            final matchesColor =
                _selectedColorFilter == null ||
                (s.tag.color != null &&
                    s.tag.color == _selectedColorFilter!.value);

            if (_isSearching) {
              return matchesSearch && matchesColor;
            }

            // When not searching, show items if they match color AND (have data OR filter is active)
            // If filter is active, show matching tags even if count is 0
            if (_selectedColorFilter != null) {
              return matchesColor;
            }

            // Default view: Show only used tags
            return s.count > 0;
          }).toList();

          // Sort by Last Used
          filteredStats.sort((a, b) {
            if (a.lastUsed == null) return 1;
            if (b.lastUsed == null) return -1;
            return b.lastUsed!.compareTo(a.lastUsed!);
          });

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Budget Warning Widget
              const SliverToBoxAdapter(child: FolderWarningWidget()),

              // Insights Pod (Hide when searching or filtering)
              if (!_isSearching &&
                  _selectedColorFilter == null &&
                  (mostUsed != null || highestSpend != null))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: _InsightsPod(
                      mostUsed: mostUsed,
                      highestSpend: highestSpend,
                    ),
                  ),
                ),

              // List Header
              if (filteredStats.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Row(
                      children: [
                        Text(
                          _isSearching
                              ? "SEARCH RESULTS"
                              : _selectedColorFilter != null
                              ? "FILTERED FOLDERS"
                              : "ALL FOLDERS",
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${filteredStats.length}",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (filteredStats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyReportPlaceholder(
                    message: _selectedColorFilter != null
                        ? "No folders found with this color"
                        : "This place feels empty...",
                    icon: HugeIcons.strokeRoundedFolder02,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _FunkyTagTile(stat: filteredStats[index]),
                    childCount: filteredStats.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // ... (Rest of your existing code: _buildGlassFab, _showCreateTagSheet, _TagStat, _InsightsPod, _InsightCard, _FunkyTagTile) ...
  // [Note: Keep all the code below `build` exactly as it was in your snippet]

  Widget _buildGlassFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCreateTagSheet(context),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Folder",
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateTagSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    Color? selectedColor; // null means no color

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              0,
              24,
              0,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Text(
                        "Create New Folder",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Name Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    controller: nameController,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: "Folder Name",
                      hintText: "e.g. Office Commute, London 2026",
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.4),
                      prefixIcon: Icon(
                        Icons.label_outline_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Color Picker
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Folder Color",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: _tagColors.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final Color? color = index == 0
                          ? null
                          : _tagColors[index - 1];
                      final isSelected = color == selectedColor;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedColor = color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color:
                                color ??
                                theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 3,
                                  )
                                : color == null
                                ? Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withOpacity(0.5),
                                    width: 1,
                                  )
                                : null,
                            boxShadow: [
                              if (isSelected && color != null)
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: color == null
                                      ? theme.colorScheme.primary
                                      : (ThemeData.estimateBrightnessForColor(
                                                  color,
                                                ) ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black),
                                )
                              : color == null
                              ? Icon(
                                  Icons.not_interested_rounded,
                                  size: 20,
                                  color: theme.colorScheme.outline,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Create Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final metaProvider = Provider.of<MetaProvider>(
                          context,
                          listen: false,
                        );

                        await metaProvider.addTag(
                          name,
                          color: selectedColor?.value,
                        );

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        "Create Folder",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- DATA MODEL ---
class _TagStat {
  final Tag tag;
  final double totalIncome;
  final double totalExpense;
  final DateTime? lastUsed;
  final int count;

  _TagStat({
    required this.tag,
    required this.totalIncome,
    required this.totalExpense,
    this.lastUsed,
    required this.count,
  });
}

// --- WIDGETS ---

class _InsightsPod extends StatelessWidget {
  final _TagStat? mostUsed;
  final _TagStat? highestSpend;

  const _InsightsPod({this.mostUsed, this.highestSpend});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (mostUsed != null)
            Expanded(
              child: _InsightCard(
                label: "Most Used",
                value: mostUsed!.tag.name,
                subValue: "${mostUsed!.count} times",
                icon: Icons.repeat_rounded,
                color: Colors.blueAccent,
              ),
            ),
          if (mostUsed != null && highestSpend != null)
            const SizedBox(width: 12),
          if (highestSpend != null)
            Expanded(
              child: _InsightCard(
                label: "Top Spend",
                value: highestSpend!.tag.name,
                subValue: NumberFormat.compactCurrency(
                  symbol: currencySymbol,
                ).format(highestSpend!.totalExpense),
                icon: Icons.trending_up_rounded,
                color: Colors.orangeAccent,
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.label,
    required this.value,
    required this.subValue,
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
        // border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subValue,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FunkyTagTile extends StatelessWidget {
  final _TagStat stat;

  const _FunkyTagTile({required this.stat});

  // Color _generateColor(String name) {
  //   final hash = name.codeUnits.fold(0, (val, byte) => val + byte);
  //   final colors = [
  //     Colors.blue,
  //     Colors.red,
  //     Colors.green,
  //     Colors.orange,
  //     Colors.purple,
  //     Colors.teal,
  //     Colors.pink,
  //     Colors.indigo,
  //   ];
  //   return colors[hash % colors.length];
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    // Use tag.color if available, else fallback to primary
    final Color tagColor = stat.tag.color != null
        ? Color(stat.tag.color!)
        : theme.colorScheme.primary;

    final appColors = theme.extension<AppColors>();
    final metaProvider = Provider.of<MetaProvider>(context);

    // Check Event Mode Status
    final now = DateTime.now();
    final bool isEventActive =
        metaProvider.isEventModeEnabled(stat.tag.id) &&
        stat.tag.eventStartDate != null &&
        stat.tag.eventEndDate != null &&
        now.isAfter(
          stat.tag.eventStartDate!.subtract(const Duration(seconds: 1)),
        ) &&
        now.isBefore(stat.tag.eventEndDate!.add(const Duration(days: 1)));

    // Calculate Net Balance
    final double netBalance = stat.totalIncome - stat.totalExpense;
    final bool isPositive = netBalance >= 0;
    final Color balanceColor = isPositive
        ? (appColors?.income ?? Colors.green)
        : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isEventActive
            ? tagColor.withAlpha(20)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: isEventActive
            ? Border.all(color: tagColor, width: 1)
            : Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: RouteSettings(
                name: 'TagDetails',
                arguments: stat.tag.id,
              ),
              builder: (_) =>
                  TagDetailsScreen(tag: stat.tag, parentTagIds: [stat.tag.id]),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEventActive ? tagColor : tagColor.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFolder02,
                    size: 20,
                    color: isEventActive ? Colors.white : tagColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stat.tag.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.lastUsed != null
                          ? "Last used on ${DateFormat('MMM d').format(stat.lastUsed!)}"
                          : "Unused",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats (Net Balance Only)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$currencySymbol${NumberFormat.compact().format(netBalance.abs())}",
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontFamily: 'momo',
                    ),
                  ),
                  if (isEventActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Event Active",
                          style: TextStyle(
                            color: tagColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (stat.count > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${stat.count} items",
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
