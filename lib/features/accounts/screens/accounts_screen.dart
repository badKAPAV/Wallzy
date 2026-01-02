import 'dart:math';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/account_income_details_screen.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/screens/account_details_screen.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';

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

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    HapticFeedback.lightImpact();
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
    final theme = Theme.of(context);

    if (accountProvider.isLoading || transactionProvider.isLoading) {
      return const _AccountsLoadingSkeleton();
    }

    // --- Sorting Logic ---
    List<Account> tempAccounts = [...accountProvider.accounts];
    List<Account> sortedAccounts = [];

    int primaryIndex = tempAccounts.indexWhere(
      (acc) => acc.isPrimary && acc.bankName.toLowerCase() != 'cash',
    );
    if (primaryIndex != -1) {
      sortedAccounts.add(tempAccounts.removeAt(primaryIndex));
    }

    Account? cashAccount;
    int cashIndex = tempAccounts.indexWhere(
      (acc) => acc.bankName.toLowerCase() == 'cash',
    );
    if (cashIndex != -1) cashAccount = tempAccounts.removeAt(cashIndex);

    tempAccounts.sort((a, b) => a.bankName.compareTo(b.bankName));
    sortedAccounts.addAll(tempAccounts);
    if (cashAccount != null) sortedAccounts.add(cashAccount);

    final allAccounts = sortedAccounts;
    final selectedAccount = allAccounts.isNotEmpty
        ? allAccounts[_selectedAccountIndex]
        : null;

    final recentTransactions = selectedAccount != null
        ? transactionProvider.transactions
              .where((tx) => tx.accountId == selectedAccount.id)
              .take(20)
              .toList()
        : <TransactionModel>[];

    // --- Net Worth Calculation ---
    double totalBalance = 0;
    double totalDue = 0;
    for (final account in allAccounts) {
      final balance = accountProvider.getBalanceForAccount(
        account,
        transactionProvider.transactions,
      );
      if (account.accountType == 'credit') {
        if (balance < 0) totalDue += -balance;
      } else {
        totalBalance += balance;
      }
    }
    final netWorth = totalBalance - totalDue;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Clean, standard large app bar that handles scaling correctly
          SliverAppBar.large(
            title: const Text('My Wallet'),
            centerTitle: false,
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            pinned: true,
          ),

          // 1. Net Worth Dashboard
          SliverToBoxAdapter(
            child: _NetWorthBlock(
              totalBalance: totalBalance,
              totalDue: totalDue,
              netWorth: netWorth,
            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 2. The Cards Carousel
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: allAccounts.length,
                itemBuilder: (context, index) {
                  final account = allAccounts[index];
                  final balance = accountProvider.getBalanceForAccount(
                    account,
                    transactionProvider.transactions,
                  );

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double page = _pageController.hasClients
                          ? _pageController.page ??
                                _selectedAccountIndex.toDouble()
                          : _selectedAccountIndex.toDouble();
                      double diff = (page - index);
                      double scale = max(0.9, 1 - diff.abs() * 0.1);
                      double rotation = diff * -0.1;

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(0, 2, 0.001)
                          ..rotateY(rotation)
                          ..scale(scale),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: _PremiumAccountCard(
                      account: account,
                      balance: balance,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => account.accountType == 'credit'
                                ? AccountIncomeDetailsScreen(account: account)
                                : AccountDetailsScreen(account: account),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Carousel Indicator
          SliverToBoxAdapter(
            child: _buildPageIndicator(context, allAccounts.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // 3. Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAccount?.bankName ?? "Select Account",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("Recent Activity", style: theme.textTheme.bodySmall),
                    ],
                  ),
                  if (selectedAccount != null)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                selectedAccount.accountType == 'credit'
                                ? AccountIncomeDetailsScreen(
                                    account: selectedAccount,
                                  )
                                : AccountDetailsScreen(
                                    account: selectedAccount,
                                  ),
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No transactions yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            GroupedTransactionList(
              transactions: recentTransactions,
              onTap: (tx) => _showTransactionDetails(context, tx),
              useSliver: true,
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildGlassFab(context),
    );
  }

  Widget _buildPageIndicator(BuildContext context, int count) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 6.0,
          width: _selectedAccountIndex == index ? 20.0 : 6.0,
          decoration: BoxDecoration(
            color: _selectedAccountIndex == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Widget _buildGlassFab(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: FloatingActionButton.extended(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            highlightElevation: 0,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
              );
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Add Account'),
          ),
        ),
      ),
    );
  }
}

// --- 1. NET WORTH BLOCK ---
class _NetWorthBlock extends StatelessWidget {
  final double totalBalance;
  final double totalDue;
  final double netWorth;

  const _NetWorthBlock({
    required this.totalBalance,
    required this.totalDue,
    required this.netWorth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            "Total Net Worth",
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(netWorth),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: "Assets",
                  amount: currencyFormat.format(totalBalance),
                  color: const Color(0xFF4CAF50), // Green
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  label: "Liabilities",
                  amount: currencyFormat.format(totalDue),
                  color: const Color(0xFFE53935), // Red
                  icon: Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// --- 2. PREMIUM ACCOUNT CARD ---
class _PremiumAccountCard extends StatelessWidget {
  final Account account;
  final double balance;
  final VoidCallback onTap;

  const _PremiumAccountCard({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  // Re-using the gradient logic but making it punchier
  Gradient _getGradient(String bankName) {
    final name = bankName.toLowerCase();
    Color start, end;

    if (name.contains('hdfc')) {
      start = const Color(0xFF003B73);
      end = const Color(0xFF0074D9);
    } else if (name.contains('icici')) {
      start = const Color(0xFFD35400);
      end = const Color(0xFFFFA040);
    } else if (name.contains('sbi')) {
      start = const Color(0xFF007EA3);
      end = const Color(0xFF4FB3D9);
    } else if (name.contains('axis')) {
      start = const Color(0xFF8E0E2C);
      end = const Color(0xFFD93050);
    } else if (name.contains('cash')) {
      start = const Color(0xFF2E7D32);
      end = const Color(0xFF66BB6A);
    } else {
      start = const Color(0xFF424242);
      end = const Color(0xFF757575);
    } // Default Dark Grey

    return LinearGradient(
      colors: [start, end],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _getIcon(String bankName, String type) {
    if (bankName.toLowerCase() == 'cash') return Icons.wallet_rounded;
    if (type == 'credit') return Icons.credit_card;
    return Icons.account_balance_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final creditDue = -balance;
    final isCredit = account.accountType == 'credit';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: _getGradient(account.bankName),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _getGradient(
                account.bankName,
              ).colors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Noise/Texture Overlay (simulated)
              Positioned.fill(child: CustomPaint(painter: _PatternPainter())),

              // Glassmorphism Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Bank Icon & Name
                        Row(
                          children: [
                            Icon(
                              _getIcon(account.bankName, account.accountType),
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              account.bankName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        // Chip Icon
                        if (account.bankName.toLowerCase() != 'cash')
                          const Icon(
                            Icons.nfc_rounded,
                            color: Colors.white54,
                            size: 28,
                          ),
                      ],
                    ),
                    const Spacer(),

                    // Balance
                    Text(
                      isCredit ? "Outstanding" : "Balance",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      currencyFormat.format(isCredit ? creditDue : balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    if (isCredit && (account.creditLimit ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      // Credit Limit Progress
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    ((creditDue > 0 ? creditDue : 0) /
                                            (account.creditLimit ?? 1))
                                        .clamp(0.0, 1.0),
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Limit: ${currencyFormat.format(account.creditLimit)}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Footer (Holder & Number)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          account.accountHolderName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (!isCredit)
                          Text(
                            "•••• ${account.accountNumber}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Decorative Painter for Card background
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 80, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 4. LOADING SKELETON (Updated aspect ratios) ---
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
            child: Container(
              height: 150,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
