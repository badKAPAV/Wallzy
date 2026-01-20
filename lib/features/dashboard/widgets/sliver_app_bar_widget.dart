import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/dashboard/widgets/rotating_balance.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/dashboard/widgets/analytics_widget.dart';

class HomeSliverAppBar extends StatefulWidget {
  final Timeframe selectedTimeframe;

  const HomeSliverAppBar({super.key, required this.selectedTimeframe});

  @override
  State<HomeSliverAppBar> createState() => _HomeSliverAppBarState();
}

class _HomeSliverAppBarState extends State<HomeSliverAppBar> {
  bool _isBalanceVisible = false;

  String _getTrendData(TransactionProvider provider, String type) {
    double current = 0;
    double previous = 0;
    final now = DateTime.now();
    final timeframe = widget.selectedTimeframe;

    if (timeframe == Timeframe.weeks) {
      if (type == 'income') {
        current = provider.thisWeekIncome;
        previous = provider.lastWeekIncome;
      } else {
        current = provider.thisWeekExpense;
        previous = provider.lastWeekExpense;
      }
    } else if (timeframe == Timeframe.months) {
      if (type == 'income') {
        current = provider.thisMonthIncome;
        previous = provider.lastMonthIncome;
      } else {
        current = provider.thisMonthExpense;
        previous = provider.lastMonthExpense;
      }
    } else if (timeframe == Timeframe.years) {
      final startOfYear = DateTime(now.year, 1, 1);
      final nextYear = DateTime(now.year + 1, 1, 1);
      final startOfLastYear = DateTime(now.year - 1, 1, 1);
      final endOfLastYear = DateTime(now.year, 1, 1);

      current = provider.getTotal(
        start: startOfYear,
        end: nextYear,
        type: type,
      );
      previous = provider.getTotal(
        start: startOfLastYear,
        end: endOfLastYear,
        type: type,
      );
    }

    if (previous == 0) {
      if (current == 0) return "0%";
      return "+100%";
    }

    final percent = ((current - previous) / previous) * 100;
    final sign = percent >= 0 ? "+" : "";
    return "$sign${percent.toStringAsFixed(0)}%";
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

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final totalCash = accountProvider.getTotalAvailableCash(
      txProvider.transactions,
    );
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 260,
      collapsedHeight: 60,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -170,
              right: -180,
              left: -180,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: SvgPicture.asset(
                  'assets/vectors/home_gradient_vector.svg',
                  width: 300,
                  height: 300,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () => _showBalancePrivacyModal(context),
                      behavior: HitTestBehavior.translucent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Total Balance",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedHelpCircle,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.5, end: 0),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.vibrate();
                        setState(() => _isBalanceVisible = !_isBalanceVisible);
                      },
                      child: accountProvider.isLoading
                          ? Shimmer.fromColors(
                              baseColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              highlightColor: theme.colorScheme.surface,
                              child: Container(
                                width: 200,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : RollingBalance(
                              isVisible: _isBalanceVisible,
                              symbol: settingsProvider.currencySymbol,
                              amount: totalCash,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.1,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _HeaderChip(
                          icon: Icons.trending_up,
                          label: "Income",
                          value: _getTrendData(txProvider, 'income'),
                          color: Colors.greenAccent.shade700,
                        ),
                        const SizedBox(width: 12),
                        _HeaderChip(
                          icon: Icons.trending_down,
                          label: "Spend",
                          value: _getTrendData(txProvider, 'expense'),
                          color: Colors.orangeAccent.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'ledgr',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchTransactionsScreen(),
              ),
            ),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
      centerTitle: true,
      titleSpacing: 20,
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
