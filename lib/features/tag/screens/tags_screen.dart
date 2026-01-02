import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/tag/screens/tag_details_screen.dart';
import 'package:wallzy/core/themes/theme.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        // SWITCHABLE TITLE
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search tags...",
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
            : const Text("Tags", style: TextStyle(fontWeight: FontWeight.bold)),
        // ACTION ICON
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              if (_isSearching) {
                _stopSearch();
              } else {
                _startSearch();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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

          // 2. Identify "Hero" Tags (Most Used / Highest Spend)
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
            final matchesSearch = s.tag.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
            if (_isSearching) {
              return matchesSearch;
            }
            // When not searching, remove unused tags
            return s.count > 0;
          }).toList();

          // Sort by Last Used
          filteredStats.sort((a, b) {
            if (a.lastUsed == null) return 1;
            if (b.lastUsed == null) return -1;
            return b.lastUsed!.compareTo(a.lastUsed!);
          });

          // Single Scrollable List for the whole body
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            physics: const BouncingScrollPhysics(),
            children: [
              // Insights Pod (Hide when searching to focus on results)
              if (!_isSearching && (mostUsed != null || highestSpend != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: _InsightsPod(
                    mostUsed: mostUsed,
                    highestSpend: highestSpend,
                  ),
                ),

              // List Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  _isSearching
                      ? "SEARCH RESULTS (${filteredStats.length})"
                      : "ALL TAGS (${filteredStats.length})",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),

              if (filteredStats.isEmpty)
                const _EmptyState()
              else
                ...filteredStats.map((stat) => _FunkyTagTile(stat: stat)),
            ],
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
                  symbol: '₹',
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
        // border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
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

    // Use tag.color if available, else fallback to primary
    final Color tagColor = stat.tag.color != null
        ? Color(stat.tag.color!)
        : theme.colorScheme.primary;

    final appColors = theme.extension<AppColors>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TagDetailsScreen(tag: stat.tag)),
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
                  color: tagColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stat.tag.name.isNotEmpty
                        ? stat.tag.name[0].toUpperCase()
                        : '#',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tagColor,
                    ),
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
                        Text('#', style: TextStyle(color: tagColor)),
                        const SizedBox(width: 4),
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

              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (stat.totalExpense > 0)
                    Text(
                      "-₹${NumberFormat.compact().format(stat.totalExpense)}",
                      style: TextStyle(
                        color: appColors?.expense ?? Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (stat.totalIncome > 0)
                    Text(
                      "+₹${NumberFormat.compact().format(stat.totalIncome)}",
                      style: TextStyle(
                        color: appColors?.income ?? Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (stat.totalExpense == 0 && stat.totalIncome == 0)
                    Text(
                      "${stat.count} items",
                      style: TextStyle(
                        color: colorScheme.outline,
                        fontSize: 12,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "No tags found",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
