import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/screens/account_details_screen.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
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

  void _showDeleteConfirmation(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
            'Are you sure you want to delete the account "${account.bankName}"? This will not affect existing transactions linked to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AccountProvider>(context, listen: false)
                  .deleteAccount(account.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user!.uid;

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
        : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: Column(
        children: [
          if (accountProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (allAccounts.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No accounts found. Add one to get started!'),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: allAccounts.length,
                    itemBuilder: (context, index) {
                      final account = allAccounts[index];

                      final accountTransactions = transactionProvider
                          .transactions.where((tx) => tx.accountId == account.id);

                      final income = accountTransactions
                          .where((tx) => tx.type == 'income')
                          .fold(0.0, (sum, tx) => sum + tx.amount);
                      final expense = accountTransactions
                          .where((tx) => tx.type == 'expense')
                          .fold(0.0, (sum, tx) => sum + tx.amount);
                      final balance = income - expense;

                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double page = _pageController.hasClients
                              ? _pageController.page ?? _selectedAccountIndex.toDouble()
                              : _selectedAccountIndex.toDouble();
                          double scale =
                              max(0.85, 1 - (page - index).abs() * 0.15);

                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: _AccountCard(
                          account: account,
                          income: income,
                          expense: expense,
                          balance: balance,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailsScreen(account: account),
                              ),
                            );
                          },
                          onDelete: () => _showDeleteConfirmation(context, account),
                          onEdit: () {
                             Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AddEditAccountScreen(
                                        account: account)));
                          },
                          onSetPrimary: () => accountProvider.setPrimaryAccount(account.id),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentGeometry.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          Expanded(
            child: recentTransactions.isEmpty
                ? const Center(
                    child: Text('No transactions for this account yet.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: recentTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = recentTransactions[index];
                      return TransactionListItem(
                        transaction: tx,
                        onTap: () => _showTransactionDetails(context, tx),
                      );
                    },
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

class _AccountCard extends StatelessWidget {
  final Account account;
  final double income;
  final double expense;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  const _AccountCard({
    required this.account,
    required this.income,
    required this.expense,
    required this.balance,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isCash = account.bankName.toLowerCase() == 'cash';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primaryFixed,
                theme.colorScheme.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    account.bankName,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
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
                  Builder(builder: (context) {
                    final isCashAccount =
                        account.bankName.toLowerCase() == 'cash';
                    final canSetPrimary = !account.isPrimary;

                    // Hide menu if there are no available actions
                    if (!canSetPrimary && isCashAccount) {
                      return const SizedBox.shrink();
                    }

                    return PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: theme.colorScheme.onPrimary),
                      onSelected: (value) {
                        if (value == 'primary') onSetPrimary();
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (ctx) => [
                        if (canSetPrimary)
                          const PopupMenuItem(
                              value: 'primary', child: Text('Set as Primary')),
                        if (!isCashAccount)
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                        if (!isCashAccount)
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete')),
                      ],
                    );
                  }),
                ],
              ),
              const Spacer(),
              if (!isCash)
                Text(
                  'XXXX XXXX XXXX ${account.accountNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      letterSpacing: 2,
                      fontFamily: 'monospace'),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                account.accountHolderName,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
              ),
                  // _BalanceItem(
                  //     label: 'Income',
                  //     amount: currencyFormat.format(income),
                  //     color: Colors.greenAccent),
                  // _BalanceItem(
                  //     label: 'Expense',
                  //     amount: currencyFormat.format(expense),
                  //     color: Colors.redAccent),
                  _BalanceItem(
                      label: 'Balance',
                      amount: currencyFormat.format(balance),
                      color: theme.colorScheme.onPrimary),
                ],
              ),
            ],
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color.withOpacity(0.8))),
        Text(amount, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}