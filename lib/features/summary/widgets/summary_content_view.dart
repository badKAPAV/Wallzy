import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart'; // Assuming you use this based on previous context
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/summary/widgets/summary_pie_chart.dart';
import 'package:wallzy/features/summary/widgets/summary_monthly_graph.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/screens/category_transactions_screen.dart';

class SummaryContentView extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onTransactionTap;
  final DateTime monthDate;

  const SummaryContentView({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
    required this.monthDate,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return _buildEmptyState(context);

    final settings = Provider.of<SettingsProvider>(context);
    final currencySymbol = settings.currencySymbol;
    final theme = Theme.of(context);

    // --- Data Processing ---
    double totalIncome = 0;
    double totalExpense = 0;

    // Using a sorted map for chart efficiency
    final Map<String, double> expenseCategories = {};
    final Map<String, double> accountSpending = {};
    final List<TransactionModel> expenseTransactions = [];

    for (var tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        expenseTransactions.add(tx);
        totalExpense += tx.amount;

        // Categorize
        expenseCategories[tx.category] =
            (expenseCategories[tx.category] ?? 0) + tx.amount;

        // Account Spending
        if (tx.accountId != null) {
          accountSpending[tx.accountId!] =
              (accountSpending[tx.accountId!] ?? 0) + tx.amount;
        }
      }
    }

    final savings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome * 100) : 0.0;

    // Sort Top items
    final topCategories = expenseCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Categories = topCategories
        .take(3)
        .toList(); // Changed to 3 as requested

    final topAccounts = accountSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top4Accounts = topAccounts.take(4).toList();

    expenseTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    final top3HighestSpends = expenseTransactions.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 100, bottom: 50),
      child: Column(
        children: [
          // 1. THE HERO CHART SECTION
          // We wrap this in a container to give it distinct separation
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 280, // Slightly compact
                  child: SummaryPieChart(
                    categoryAmounts: expenseCategories,
                    totalAmount: totalExpense,
                    currencySymbol: currencySymbol,
                  ),
                ),

                const SizedBox(height: 24),

                // Key Health Metrics Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AllTransactionsScreen(),
                              ),
                            );
                          },
                          child: _buildHealthPill(
                            context,
                            'Income',
                            totalIncome,
                            currencySymbol,
                            Colors.green,
                            HugeIcons.strokeRoundedArrowUp01,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AllTransactionsScreen(),
                              ),
                            );
                          },
                          child: _buildHealthPill(
                            context,
                            'Savings',
                            savings,
                            currencySymbol,
                            savings >= 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            savings >= 0
                                ? HugeIcons.strokeRoundedPiggyBank
                                : HugeIcons.strokeRoundedAlert02,
                            subtitle: '${savingsRate.toStringAsFixed(0)}%',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. TREND GRAPH
          DailyExpenseGraph(transactions: transactions, monthDate: monthDate),

          const SizedBox(height: 32),

          // 3. WHERE THE MONEY WENT (Categories)
          if (top3Categories.isNotEmpty) ...[
            _buildSectionTitle(context, "Top Categories"),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: top3Categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = top3Categories[index];
                final percent = (entry.value / totalExpense);
                final color = Colors
                    .primaries[entry.key.hashCode % Colors.primaries.length];

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryTransactionsScreen(
                          categoryName: entry.key,
                          categoryType: 'expense',
                          initialSelectedDate: monthDate,
                        ),
                      ),
                    );
                  },
                  child:
                      _buildCategoryBar(
                            context,
                            entry.key,
                            entry.value,
                            percent,
                            color,
                            currencySymbol,
                          )
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideX(begin: 0.1),
                );
              },
            ),
            const SizedBox(height: 32),
          ],

          // 3. SPENDING BY ACCOUNT
          if (top4Accounts.isNotEmpty) ...[
            _buildSectionTitle(context, "Spending by Account"),
            SizedBox(
              height: 130, // Fixed height for horizontal list
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: top4Accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildAccountCard(
                    context,
                    top4Accounts[index],
                    currencySymbol,
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],

          // 4. BIGGEST SPENDERS
          if (top3HighestSpends.isNotEmpty) ...[
            _buildSectionTitle(context, "Highest Transactions"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: top3HighestSpends
                      .map(
                        (tx) => _buildTransactionTile(
                          context,
                          tx,
                          currencySymbol,
                          onTransactionTap,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthPill(
    BuildContext context,
    String label,
    double amount,
    String symbol,
    Color color,
    dynamic icon, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$symbol${NumberFormat.compact().format(amount)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  dynamic _getHugeIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'restaurant':
        return HugeIcons.strokeRoundedPizza01; // Safer choice
      case 'shopping':
        return HugeIcons.strokeRoundedShoppingBag01;
      case 'transport':
      case 'travel':
        return HugeIcons.strokeRoundedCar02;
      case 'entertainment':
      case 'fun':
        return HugeIcons.strokeRoundedMusicNote01;
      case 'salary':
      case 'income':
        return HugeIcons.strokeRoundedMoney03;
      case 'bills':
      case 'utilities':
        return HugeIcons.strokeRoundedInvoice01;
      case 'health':
      case 'medical':
        return HugeIcons.strokeRoundedBodyPartMuscle;
      case 'education':
        return HugeIcons.strokeRoundedDiploma;
      case 'groceries':
        return HugeIcons.strokeRoundedShoppingCart01;
      case 'investment':
        return HugeIcons.strokeRoundedBitcoin01;
      case 'others':
      default:
        return HugeIcons.strokeRoundedArchive02;
    }
  }

  Widget _buildCategoryBar(
    BuildContext context,
    String category,
    double amount,
    double percent,
    Color color,
    String symbol,
  ) {
    final icon = _getHugeIconForCategory(category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: HugeIcon(icon: icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          // Bar and Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$symbol${NumberFormat('#,##0').format(amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.fastOutSlowIn,
                      height: 8,
                      width: MediaQuery.of(context).size.width * 0.5 * percent,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    MapEntry<String, double> entry,
    String symbol,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Consumer<AccountProvider>(
            builder: (context, provider, _) {
              // Assuming you have this helper, or use the provider to fetch by ID
              final name = provider.getAccountName(entry.key);
              return Text(
                name.isNotEmpty ? name : 'Unknown',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          const Spacer(),
          Text(
            '$symbol${NumberFormat.compact().format(entry.value)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const Text(
            "Spent",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionModel tx,
    String symbol,
    Function onTap,
  ) {
    return ListTile(
      onTap: () => onTap(tx),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCircleArrowUp01,
          size: 20,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
      title: Text(
        tx.description.isNotEmpty ? tx.description : tx.category,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('MMM d, yyyy').format(tx.timestamp),
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 12,
        ),
      ),
      trailing: Text(
        '$symbol${NumberFormat('#,##0').format(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAnalytics01,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No data for this month',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
