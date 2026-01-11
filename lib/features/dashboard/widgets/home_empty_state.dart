import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/settings/screens/app_settings_screen.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 100.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Welcoming Visual
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedRocket01,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // 2. Clear Value Proposition
            Text(
              "Welcome to Ledgr!",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Let's get your financial dashboard ready.\n\n\nChoose how you want to start:",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 3. The "Hero" Action (Auto-Record)
            // This is the most important feature, so it gets the biggest card.
            _GuideCard(
              title: "Activate Auto-Tracking",
              subtitle:
                  "The magic way. Ledgr uses your notifications to save transactions automatically.",
              icon: HugeIcons.strokeRoundedAiMagic,
              color: Colors.purpleAccent, // Or theme.primary
              isHero: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Secondary Action (Manual)
            _GuideCard(
              title: "Add a Transaction",
              subtitle: "Log your first expense or income.",
              icon: HugeIcons.strokeRoundedInvoice01,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditTransactionScreen(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 5. Tertiary Action (Setup)
            _GuideCard(
              title: "Setup Accounts",
              subtitle: "Add bank accounts or wallets.",
              icon: HugeIcons.strokeRoundedWallet01,
              color: Colors.orangeAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isHero;

  const _GuideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isHero
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: isHero
            ? Border.all(
                color: theme.colorScheme.primary.withOpacity(0.5),
                width: 1.5,
              )
            : Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              ),
        boxShadow: isHero
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHero
                        ? theme.colorScheme.surface
                        : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: icon,
                    size: 24,
                    color: isHero ? theme.colorScheme.primary : color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isHero
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isHero
                              ? theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.8)
                              : theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHero)
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
