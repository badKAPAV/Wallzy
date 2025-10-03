import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/account_income_details_screen.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/screens/account_details_screen.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late PageController _pageController;
  int _selectedAccountIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);

    _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_selectedAccountIndex != newIndex) {
        setState(() {
          _selectedAccountIndex = newIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPageIndicator(int count) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: _selectedAccountIndex == index ? 24.0 : 8.0,
          decoration: BoxDecoration(
            color: _selectedAccountIndex == index ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  void _showTransactionDetails(
      BuildContext context,
      TransactionModel transaction,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
      List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      String key;
      if (txDate.isAtSameMomentAs(today)) {
        key = 'Today';
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('d MMMM, yyyy').format(txDate);
      }
      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);

    if (accountProvider.isLoading || transactionProvider.isLoading) {
      return const _AccountsLoadingSkeleton();
    }

    // --- Account Sorting Logic ---
    List<Account> tempAccounts = [...accountProvider.accounts];
    List<Account> sortedAccounts = [];

    // 1. Find, extract, and add the primary account first (if it's not Cash)
    int primaryIndex = tempAccounts
        .indexWhere((acc) => acc.isPrimary && acc.bankName.toLowerCase() != 'cash');
    if (primaryIndex != -1) {
      sortedAccounts.add(tempAccounts.removeAt(primaryIndex));
    }

    // 2. Find and extract the Cash account to be added last
    Account? cashAccount;
    int cashIndex =
        tempAccounts.indexWhere((acc) => acc.bankName.toLowerCase() == 'cash');
    if (cashIndex != -1) {
      cashAccount = tempAccounts.removeAt(cashIndex);
    } else {
      // The cash account is now a real entity managed by the provider.
      // If it's not here, it might be loading. We no longer create a dummy.
    }

    // 3. Sort the rest of the accounts alphabetically and add them
    tempAccounts.sort((a, b) => a.bankName.compareTo(b.bankName));
    sortedAccounts.addAll(tempAccounts);

    // 4. Add the Cash account at the very end
    if (cashAccount != null) {
      sortedAccounts.add(cashAccount);
    }
    final allAccounts = sortedAccounts;

    final selectedAccount =
        allAccounts.isNotEmpty ? allAccounts[_selectedAccountIndex] : null;
    final recentTransactions = selectedAccount != null
        ? transactionProvider.transactions
            .where((tx) => tx.accountId == selectedAccount.id)
            .take(10)
            .toList()
        : <TransactionModel>[];
    final groupedTransactions = _groupTransactionsByDate(recentTransactions);

    // --- Overall Summary Calculation ---
    double totalBalance = 0;
    double totalDue = 0;

    for (final account in allAccounts) {
      final balance = accountProvider.getBalanceForAccount(account, transactionProvider.transactions);
      if (account.accountType == 'credit') {
        if (balance < 0) {
          totalDue += -balance; // balance is negative, so add its positive value
        }
      } else {
        totalBalance += balance;
      }
    }
    final netWorth = totalBalance - totalDue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: allAccounts.isEmpty
          ? const Center(
              child: Text('No accounts found. Add one to get started!'),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _TotalBalanceCard(
                    totalBalance: totalBalance,
                    totalDue: totalDue,
                    netWorth: netWorth,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: allAccounts.length,
                          itemBuilder: (context, index) {
                            final account = allAccounts[index];
                            final balance = accountProvider.getBalanceForAccount(
                                account, transactionProvider.transactions);

                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double page = _pageController.hasClients
                                    ? _pageController.page ??
                                        _selectedAccountIndex.toDouble()
                                    : _selectedAccountIndex.toDouble();
                                double scale = max(
                                    0.85, 1 - (page - index).abs() * 0.15);

                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: _AccountCard(
                                account: account,
                                balance: balance,
                                onTap: () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) {
                                    if (account.accountType == 'credit') {
                                      return AccountIncomeDetailsScreen(
                                          account: account);
                                    }
                                    return AccountDetailsScreen(
                                        account: account);
                                  }));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPageIndicator(allAccounts.length),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () {
                            if (selectedAccount == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => selectedAccount.accountType == 'credit'
                                    ? AccountIncomeDetailsScreen(account: selectedAccount)
                                    : AccountDetailsScreen(account: selectedAccount),
                              ),
                            );
                          },
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (recentTransactions.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No transactions for this account yet.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dateKey = groupedTransactions.keys.elementAt(index);
                        final transactionsForDate = groupedTransactions[dateKey]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                dateKey,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            ...transactionsForDate.map(
                              (tx) => TransactionListItem(
                                transaction: tx,
                                onTap: () => _showTransactionDetails(context, tx),
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: groupedTransactions.length,
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEditAccountScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _BalanceItem(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text(amount, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final double totalBalance;
  final double totalDue;
  final double netWorth;

  const _TotalBalanceCard({
    required this.totalBalance,
    required this.totalDue,
    required this.netWorth,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Net Worth',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              currencyFormat.format(netWorth),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: netWorth >= 0 ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BalanceItem(label: 'Total Balance', amount: currencyFormat.format(totalBalance), color: theme.colorScheme.onSurface),
                _BalanceItem(label: 'Total Due', amount: currencyFormat.format(totalDue), color: theme.colorScheme.onSurface),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _getOrdinal(int day) {
  if (day >= 11 && day <= 13) {
    return 'th';
  }
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

IconData _getAccountIcon(String accountType, String bankName) {
  if (bankName.toLowerCase() == 'cash') {
    return Icons.account_balance_wallet_rounded;
  }
  if (accountType == 'credit') {
    return Icons.credit_card_rounded;
  }
  return Icons.account_balance_rounded;
}

Gradient _getAccountGradient(BuildContext context, String bankName) {
  final theme = Theme.of(context);
  final name = bankName.toLowerCase();

  Color startColor = theme.colorScheme.primary;
  Color endColor = theme.colorScheme.tertiary;

  if (name.contains('hdfc')) {
    startColor = const Color(0xFF004C8F);
    endColor = const Color(0xFF0073B4);
  } else if (name.contains('icici')) {
    startColor = const Color(0xFFE65100);
    endColor = const Color(0xFFFB8C00);
  } else if (name.contains('sbi') || name.contains('state bank')) {
    startColor = const Color(0xFF0055A4);
    endColor = const Color(0xFF4196E1);
  } else if (name.contains('axis')) {
    startColor = const Color(0xFF8C1833);
    endColor = const Color(0xFFB82240);
  } else if (name.contains('cash')) {
    startColor = const Color(0xFF00897B);
    endColor = const Color(0xFF4DB6AC);
  }

  return LinearGradient(
    colors: [startColor, endColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final double balance;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account, required this.balance, required this.onTap
  });

  void _onEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditAccountScreen(account: account)),
    );
  }

  void _onDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text('Are you sure you want to delete "${account.bankName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AccountProvider>(context, listen: false).deleteAccount(account.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onSetPrimary(BuildContext context) {
    Provider.of<AccountProvider>(context, listen: false).setPrimaryAccount(account.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    const onPrimaryColor = Colors.white; // Use a constant light color for text
    final creditDue = -balance;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: _getAccountGradient(context, account.bankName)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    account.bankName,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: onPrimaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                  if (account.isPrimary) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Primary'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall,
                    )
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: onPrimaryColor),
                    onSelected: (value) {
                      if (value == 'edit') _onEdit(context);
                      if (value == 'delete') _onDelete(context);
                      if (value == 'primary') _onSetPrimary(context);
                    },
                    itemBuilder: (ctx) => [
                      if (!account.isPrimary)
                        const PopupMenuItem(value: 'primary', child: Text('Set as Primary')),
                      if (account.bankName.toLowerCase() != 'cash')
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (account.bankName.toLowerCase() != 'cash')
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (account.accountType == 'credit')
                      Builder(builder: (context) {
                        final creditLimit = account.creditLimit ?? 0;
                        final availableCredit = creditLimit > 0 ? creditLimit - creditDue : 0;
                        final usedPercent = (creditLimit > 0 && creditDue > 0) ? (creditDue / creditLimit) : 0.0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Credit Due', style: theme.textTheme.bodyMedium?.copyWith(color: onPrimaryColor.withOpacity(0.8))),
                                Text(
                                  'Available: ${currencyFormat.format(availableCredit)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: onPrimaryColor.withOpacity(0.8)),
                                ),
                              ],
                            ),
                            Text(
                              currencyFormat.format(creditDue),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: onPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (creditLimit > 0)
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: usedPercent.clamp(0.0, 1.0), // Ensure value is between 0.0 and 1.0
                                        backgroundColor: onPrimaryColor.withOpacity(0.2),
                                        valueColor: AlwaysStoppedAnimation<Color>(onPrimaryColor),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${(usedPercent * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall?.copyWith(color: onPrimaryColor)),
                                ],
                              ),
                          ],
                        );
                      })
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Balance', style: theme.textTheme.bodyMedium?.copyWith(color: onPrimaryColor.withOpacity(0.8))),
                          Text(
                            currencyFormat.format(balance),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: onPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_getAccountIcon(account.accountType, account.bankName), size: 16, color: onPrimaryColor.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      Text(
                        account.accountHolderName,
                        style: theme.textTheme.bodyMedium?.copyWith(color: onPrimaryColor.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  if (account.accountType == 'credit' && account.billingCycleDay != null)
                    Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 16, color: onPrimaryColor),
                        const SizedBox(width: 4),
                        Text('${account.billingCycleDay}${_getOrdinal(account.billingCycleDay!)} of month', style: theme.textTheme.bodyMedium?.copyWith(color: onPrimaryColor, fontWeight: FontWeight.bold)),
                      ],
                    )
                  else if (account.accountType != 'credit')
                    Text(
                      '${account.bankName.toLowerCase()!= 'cash' ? '••••' : ''} ${account.accountNumber}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onPrimaryColor.withOpacity(0.8),
                        fontFamily: 'monospace',
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

class _AccountsLoadingSkeleton extends StatelessWidget {
  const _AccountsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainer,
      highlightColor: theme.colorScheme.surfaceContainerHighest,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              elevation: 0,
              child: const SizedBox(height: 120),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  elevation: 0,
                  child: const SizedBox(height: 180),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8.0,
                      width: 8.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(height: 24, width: 200, color: Colors.white),
                  Container(height: 24, width: 60, color: Colors.white),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                child: const ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.white),
                  title: SizedBox(height: 16, width: 150),
                  subtitle: SizedBox(height: 12, width: 100),
                  trailing: SizedBox(height: 16, width: 60),
                ),
              ),
              childCount: 5,
            ),
          ),
        ],
      ),
    );
  }
}