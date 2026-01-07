import 'package:wallzy/features/currency_convert/screens/currency_convert_screen.dart';
import 'package:wallzy/features/settings/screens/app_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/screens/accounts_screen.dart';
import 'package:wallzy/features/people/screens/people_screen.dart';
import 'package:wallzy/features/profile/screens/user_profile_screen.dart';
import 'package:wallzy/features/subscription/screens/subscriptions_screen.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/tag/screens/tags_screen.dart';
import 'package:wallzy/features/guide/screens/how_to_use_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM HEADER
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withAlpha(128),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'profile_pic',
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.primary,
                          backgroundImage: user?.photoURL != null
                              ? CachedNetworkImageProvider(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Text(
                                  user?.name.substring(0, 1).toUpperCase() ??
                                      'G',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.name ?? 'Guest',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'View Profile',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withAlpha(
                                  179,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onPrimaryContainer.withAlpha(128),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. MENU ITEMS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SectionLabel(label: "DASHBOARD"),
                  _ModernDrawerItem(
                    position: 0,
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllTransactionsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _ModernDrawerItem(
                    position: 1,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Accounts',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  _SectionLabel(label: "MANAGE"),
                  _ModernDrawerItem(
                    position: 0,
                    icon: Icons.sync_alt_rounded,
                    title: 'Recurring Payments',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _ModernDrawerItem(
                    icon: Icons.people_rounded,
                    title: 'People',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PeopleScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _ModernDrawerItem(
                    position: 1,
                    icon: Icons.folder,
                    title: 'Folders',
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TagsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  _SectionLabel(label: "TOOLS"),
                  _ModernDrawerItem(
                    position: 3,
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency Convert',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CurrencyConverterScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(label: "SYSTEM"),
                  _ModernDrawerItem(
                    position: 3,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 3. FOOTER (LOGOUT)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _ModernDrawerItem(
                position: 3,
                icon: Icons.lightbulb,
                title: 'How to use',
                color: Colors.yellow,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HowToUseScreen()),
                  );
                },
              ),
            ),

            // Version Info
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                "Created with 🔥 by KAPAV",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ModernDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;
  final int position; //? 0 for top, 1 for bottom

  const _ModernDrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.color,
    this.position = 2, //? miiddle by default
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    BorderRadius borderRadius;
    switch (position) {
      case 0:
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        );
        break;
      case 1:
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        );
        break;
      case 3:
        borderRadius = BorderRadius.circular(16);
      default:
        borderRadius = BorderRadius.circular(6);
    }

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant.withAlpha(128),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
