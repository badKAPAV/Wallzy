import 'dart:math';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/account_credit_details_screen.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/screens/account_details_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

import 'package:wallzy/app_drawer.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late PageController _pageController;
  int _selectedAccountIndex = 0;

  // Cache balances to prevent expensive re-calculations during scroll animations
  final Map<String, double> _cachedBalances = {};

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

    // --- OPTIMIZATION: PRE-CALCULATE BALANCES ---
    // We clear and rebuild the cache once per build, instead of once per frame inside item builder
    _cachedBalances.clear();
    double totalBalance = 0;
    double totalDue = 0;

    for (final account in allAccounts) {
      final balance = accountProvider.getBalanceForAccount(
        account,
        transactionProvider.transactions,
      );
      _cachedBalances[account.id] = balance;

      if (account.accountType == 'credit') {
        if (balance < 0) totalDue += -balance;
      } else {
        totalBalance += balance;
      }
    }
    final netWorth = totalBalance - totalDue;
    // ---------------------------------------------

    final selectedAccount = allAccounts.isNotEmpty
        ? allAccounts[_selectedAccountIndex]
        : null;

    final recentTransactions = selectedAccount != null
        ? transactionProvider.transactions
              .where((tx) => tx.accountId == selectedAccount.id)
              .take(20)
              .toList()
        : <TransactionModel>[];

    return Scaffold(
      drawer: const AppDrawer(selectedItem: DrawerItem.accounts, isRoot: false),
      appBar: AppBar(
        title: const Text('My Accounts'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Redesigned Net Worth Dashboard
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: _NetWorthBlock(
              totalAssets: totalBalance,
              totalDebt: totalDue,
              netWorth: netWorth,
            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 2. The Cards Carousel
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageController,
                itemCount: allAccounts.length,
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  final account = allAccounts[index];
                  // Use cached balance (Fast!)
                  final balance = _cachedBalances[account.id] ?? 0.0;

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
                    // Optimization: RepaintBoundary prevents expensive redraws of shadows/gradients during rotation
                    child: RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _PremiumAccountCard(
                          account: account,
                          balance: balance,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => account.accountType == 'credit'
                                    ? AccountIncomeDetailsScreen(
                                        account: account,
                                      )
                                    : AccountDetailsScreen(account: account),
                              ),
                            );
                          },
                        ),
                      ),
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
          if (recentTransactions.isNotEmpty)
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
                        Text(
                          "Recent Activity",
                          style: theme.textTheme.bodySmall,
                        ),
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
              child: EmptyReportPlaceholder(
                message: 'Your transactions will show up here!',
                icon: HugeIcons.strokeRoundedWalletRemove02,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
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
                const SizedBox(width: 12),
                Text(
                  "Account",
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

// --- 1. NET WORTH BLOCK (REDESIGNED) ---
class _NetWorthBlock extends StatelessWidget {
  final double totalAssets;
  final double totalDebt;
  final double netWorth;

  const _NetWorthBlock({
    required this.totalAssets,
    required this.totalDebt,
    required this.netWorth,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    // Calculate flex ratios (prevent division by zero)
    final totalVolume = totalAssets + totalDebt;
    // If no data, show equal empty bars or full primary
    final int assetFlex = totalVolume == 0 ? 1 : (totalAssets * 100).toInt();
    final int debtFlex = totalVolume == 0 ? 0 : (totalDebt * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "NET WORTH",
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: netWorth >= 0
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                  color: netWorth >= 0
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      netWorth >= 0
                          ? Icons.arrow_outward_rounded
                          : Icons.trending_down_rounded,
                      color: netWorth >= 0
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      netWorth >= 0 ? "Healthy" : "Needs Attention",
                      style: TextStyle(
                        color: netWorth >= 0
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Hero Number
          Text(
            currencyFormat.format(netWorth),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 24),

          // The Two Separate Rounded Containers
          SizedBox(
            height: 12,
            child: Row(
              children: [
                // Assets portion
                if (assetFlex > 0)
                  Expanded(
                    flex: assetFlex,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                // Gap
                if (assetFlex > 0 && debtFlex > 0) const SizedBox(width: 6),
                // Liabilities portion
                if (debtFlex > 0)
                  Expanded(
                    flex: debtFlex,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Detailed Breakdown
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "ASSETS",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalAssets),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical Divider
              Container(
                height: 30,
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "LIABILITIES",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalDebt),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  void _showBalancePrivacyModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Balance Privacy",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "The balance shown is purely based on your transaction data saved on the app.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Ledgr doesn't track your bank balance even though it is present on your messages. We do it to maintain the trust between you and us.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Got it",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String bankName, String type) {
    if (bankName.toLowerCase() == 'cash') return Icons.wallet_rounded;
    if (type == 'credit') return Icons.credit_card;
    return Icons.account_balance_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final creditDue = -balance;
    final isCredit = account.accountType == 'credit';

    final screenWidth = MediaQuery.of(context).size.width;

    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: _getGradient(account.bankName),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _getGradient(account.bankName).colors.first.withAlpha(100),
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
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: account.isPrimary
                                    ? screenWidth * 0.3
                                    : screenWidth * 0.5,
                              ),
                              child: Text(
                                account.bankName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (account.isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white38,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6.0,
                                    2.0,
                                    8.0,
                                    2.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'PRIMARY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                    Row(
                      children: [
                        Text(
                          currencyFormat.format(isCredit ? creditDue : balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _showBalancePrivacyModal(context),
                          child: Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedHelpCircle,
                                  color: colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isCredit && (account.creditLimit ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      // NEW: Rounded Rectangle Split Progress Bar
                      Builder(
                        builder: (context) {
                          final limit = account.creditLimit ?? 1;
                          final used = creditDue > 0 ? creditDue : 0;
                          final utilization = (used / limit).clamp(0.0, 1.0);
                          final int usedFlex = (utilization * 100).toInt();
                          final int remainingFlex = ((1 - utilization) * 100)
                              .toInt();

                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 4,
                                  child: Row(
                                    children: [
                                      // Used Portion (Solid White)
                                      if (usedFlex > 0)
                                        Expanded(
                                          flex: usedFlex,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      // Gap
                                      if (usedFlex > 0 && remainingFlex > 0)
                                        const SizedBox(width: 4),
                                      // Remaining Portion (Translucent White)
                                      if (remainingFlex > 0)
                                        Expanded(
                                          flex: remainingFlex,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                    ],
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
                          );
                        },
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

// --- 4. LOADING SKELETON ---
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
