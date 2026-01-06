import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/settings/screens/app_settings_screen.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/tag/screens/tags_screen.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 160.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedRocket01,
            size: 64,
            color: theme.colorScheme.primary.withAlpha(128),
          ),
          const SizedBox(height: 24),
          Text(
            "Ready to make your life easier?",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Wallzy makes tracking your transactions effortless",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _ActionChip(
                label: "Create Transaction",
                icon: HugeIcons.strokeRoundedInvoice01,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditTransactionScreen(),
                  ),
                ),
              ),
              _ActionChip(
                label: "Create Subscription",
                icon: HugeIcons.strokeRoundedCalendar03,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSubscriptionScreen(),
                  ),
                ),
              ),
              _ActionChip(
                label: "Create Tag",
                icon: HugeIcons.strokeRoundedTag01,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TagsScreen()),
                ),
              ),
              _ActionChip(
                label: "Create Account",
                icon: HugeIcons.strokeRoundedWallet01,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditAccountScreen(),
                  ),
                ),
              ),
              _ActionChip(
                label: "Auto Record",
                icon: HugeIcons.strokeRoundedAiMagic,
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we should use light or dark text based on background brightness
    // But we are using themed colors. Let's stick to tonal style.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor = isDark ? color.withAlpha(50) : color.withAlpha(25);
    final contentColor = isDark ? color.withAlpha(230) : color.withAlpha(204);
    // Actually typically tonal colors are good.
    // Let's use a surfaced design.

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: contentColor.withAlpha(80), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 18, color: contentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
