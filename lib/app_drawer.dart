import 'dart:async'; // Added for Timer
import 'package:connectivity_plus/connectivity_plus.dart'; // Added
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/currency_convert/screens/currency_convert_screen.dart';
import 'package:wallzy/features/feedback/screens/feedback_screen.dart';
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
import 'package:wallzy/features/settings/provider/settings_provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _manualRetry() async {
    setState(() => _isChecking = true);
    // Artificially wait a bit to show loading feedback
    await Future.delayed(const Duration(milliseconds: 800));

    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (mounted) {
      setState(() => _isChecking = false);

      if (hasConnection) {
        // GO ONLINE GLOBALLY
        await FirebaseFirestore.instance.enableNetwork();
        if (mounted) {
          Provider.of<SettingsProvider>(
            context,
            listen: false,
          ).setOfflineStatus(false);
          ScaffoldMessenger.of(
            context,
          ).hideCurrentSnackBar(); // Hide "Back online" bar if visible
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Back online!",
                style: TextStyle(color: Colors.green.shade800),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Still offline. Please check your settings.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final user = authProvider.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOffline = settingsProvider.isOffline;

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
            // --- OFFLINE ALERT ---
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.errorContainer,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedWifiDisconnected01,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Offline Mode",
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_isChecking)
                      SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _manualRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onErrorContainer.withAlpha(
                              25,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.onErrorContainer
                                  .withAlpha(50),
                            ),
                          ),
                          child: Text(
                            "Retry",
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

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
                physics: BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SectionLabel(label: "DASHBOARD"),
                  _ModernDrawerItem(
                    position: 0,
                    icon: HugeIcons.strokeRoundedAnalytics01,
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
                    icon: HugeIcons.strokeRoundedWallet03,
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
                    icon: HugeIcons.strokeRoundedRotate02,
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
                    icon: HugeIcons.strokeRoundedUserMultiple,
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
                    icon: HugeIcons.strokeRoundedFolder02,
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

                  // Rest of the things
                  _ModernDrawerItem(
                    position: 0,
                    icon: HugeIcons.strokeRoundedMoneyExchange03,
                    title: 'Convert currency',
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
                  const SizedBox(height: 4),
                  _ModernDrawerItem(
                    position: 2,
                    icon: HugeIcons.strokeRoundedAiChat01,
                    title: 'Feedback',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _ModernDrawerItem(
                    position: 1,
                    icon: HugeIcons.strokeRoundedSettings02,
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
                icon: HugeIcons.strokeRoundedIdea01,
                title: 'How to use',
                color: Colors.yellow.shade700,
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
  final List<List<dynamic>> icon;
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
      color: colorScheme.surfaceContainer.withAlpha(200),
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
                child: HugeIcon(
                  icon: icon,
                  size: 20,
                  color: color,
                  strokeWidth: 2,
                ),
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
