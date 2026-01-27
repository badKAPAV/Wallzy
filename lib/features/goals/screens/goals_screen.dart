import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/goals/provider/goals_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/goals/models/goal_model.dart';
import 'package:wallzy/features/goals/screens/add_edit_goal_screen.dart';
import 'package:wallzy/features/goals/screens/goal_details_modal_sheet.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
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
      drawer: const AppDrawer(selectedItem: DrawerItem.goals, isRoot: false),
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
                  hintText: "Search goals",
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
                "Financial Goals",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
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
      body: Consumer3<GoalsProvider, AccountProvider, TransactionProvider>(
        builder: (context, goalsProvider, accountProvider, txProvider, child) {
          final goals = goalsProvider.goals;
          final transactions = txProvider.transactions;
          final accounts = accountProvider.accounts;

          // Process Goals (Calculate Progress)
          final goalStats = goals.map((goal) {
            double currentAmount = 0.0;

            if (goal.accountsList.isEmpty) {
              currentAmount = accountProvider.getTotalAvailableCash(
                transactions,
              );
            } else {
              // Sum link accounts
              for (var accId in goal.accountsList) {
                try {
                  final account = accounts.firstWhere((a) => a.id == accId);
                  currentAmount += accountProvider.getBalanceForAccount(
                    account,
                    transactions,
                  );
                } catch (_) {
                  // Account might be deleted
                }
              }
            }

            return _GoalStat(goal: goal, currentAmount: currentAmount);
          }).toList();

          // Filter
          final filteredStats = goalStats.where((stat) {
            final matchesSearch = stat.goal.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
            return matchesSearch;
          }).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (filteredStats.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Row(
                      children: [
                        Text(
                          _isSearching ? "SEARCH RESULTS" : "ALL GOALS",
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
                    message: _isSearching
                        ? "No goals found"
                        : "Set your first financial goal!",
                    icon: HugeIcons.strokeRoundedTarget02,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _FunkyGoalTile(stat: filteredStats[index]),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditGoalScreen()),
            );
          },
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
                  "Goal",
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
}

class _GoalStat {
  final Goal goal;
  final double currentAmount;

  _GoalStat({required this.goal, required this.currentAmount});
}

class _FunkyGoalTile extends StatelessWidget {
  final _GoalStat stat;

  const _FunkyGoalTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    final progress = (stat.currentAmount / stat.goal.targetAmount).clamp(
      0.0,
      1.0,
    );
    final percentage = (progress * 100).toInt();

    // Determine color based on progress or logic
    final Color goalColor = percentage >= 100
        ? Colors.green
        : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => GoalDetailsModalSheet(goal: stat.goal),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar/Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: goalColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: GoalIconRegistry.getIcon(stat.goal.iconKey),
                        size: 22,
                        color: goalColor,
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
                        Text(
                          stat.goal.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Target: ${DateFormat.yMMMd().format(stat.goal.targetDate)}",
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
                      Text(
                        "$currencySymbol${NumberFormat.compact().format(stat.goal.targetAmount)}",
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          fontFamily: 'momo',
                        ),
                      ),
                      Text(
                        "$percentage%",
                        style: TextStyle(
                          color: goalColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                ),
              ),
              const SizedBox(height: 8),
              // Current Amount
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Saved: $currencySymbol${NumberFormat.currency(symbol: '', decimalDigits: 0).format(stat.currentAmount)}", // Remove auto symbol to use app symbol
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
