import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
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

// Enum for Drawer Selection
enum DrawerItem {
  home,
  reports,
  accounts,
  subscriptions,
  people,
  folders,
  currencyConverter,
  howToUse,
  feedback,
  settings,
  none,
}

class AppDrawer extends StatefulWidget {
  final DrawerItem selectedItem;
  final bool isRoot; // True if this drawer is on the ROOT screen (Home)

  const AppDrawer({
    super.key,
    this.selectedItem = DrawerItem.none,
    this.isRoot = false,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isChecking = false;

  Future<void> _manualRetry() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (mounted) {
      setState(() => _isChecking = false);

      if (hasConnection) {
        await FirebaseFirestore.instance.enableNetwork();
        if (mounted) {
          Provider.of<SettingsProvider>(
            context,
            listen: false,
          ).setOfflineStatus(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Back online!",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(12),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOffline = settingsProvider.isOffline;

    return Drawer(
      backgroundColor: colorScheme.surface,
      width: MediaQuery.of(context).size.width * 0.70,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius
            .zero, // Reference image has straight edge or very subtle curve
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER (App Name + Close Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/vectors/ledgr.svg',
                        width: 34,
                        height: 34,
                        colorFilter: ColorFilter.mode(
                          colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ledgr',
                        style: TextStyle(
                          fontFamily: 'momo', // Using your custom font
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. OFFLINE ALERT (Styled minimally)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: isOffline
                  ? Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: colorScheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Offline Mode",
                              style: TextStyle(
                                color: colorScheme.error,
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
                                color: colorScheme.error,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _manualRetry,
                              child: Text(
                                "RETRY",
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 10),

            // 3. MENU ITEMS
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // --- DASHBOARD SECTION ---
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedHome01,
                    title: 'Dashboard',
                    isSelected: widget.isRoot,
                    onTap: () =>
                        _handleNav(context, const SizedBox(), DrawerItem.home),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    title: 'Reports',
                    isSelected: widget.selectedItem == DrawerItem.reports,
                    onTap: () => _handleNav(
                      context,
                      const AllTransactionsScreen(),
                      DrawerItem.reports,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedWallet03,
                    title: 'My Accounts',
                    isSelected: widget.selectedItem == DrawerItem.accounts,
                    onTap: () => _handleNav(
                      context,
                      const AccountsScreen(),
                      DrawerItem.accounts,
                    ),
                  ),

                  const SizedBox(height: 24), // Spacer between groups
                  // --- MANAGE SECTION ---
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedRotate02,
                    title: 'Recurring Payments',
                    isSelected: widget.selectedItem == DrawerItem.subscriptions,
                    onTap: () => _handleNav(
                      context,
                      const SubscriptionsScreen(),
                      DrawerItem.subscriptions,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedUserMultiple,
                    title: 'People',
                    isSelected: widget.selectedItem == DrawerItem.people,
                    onTap: () => _handleNav(
                      context,
                      const PeopleScreen(),
                      DrawerItem.people,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedFolder02,
                    title: 'Folders',
                    isSelected: widget.selectedItem == DrawerItem.folders,
                    onTap: () => _handleNav(
                      context,
                      const TagsScreen(),
                      DrawerItem.folders,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SUPPORT SECTION ---
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedMoneyExchange03,
                    title: 'Currency Converter',
                    isSelected:
                        widget.selectedItem == DrawerItem.currencyConverter,
                    onTap: () => _handleNav(
                      context,
                      const CurrencyConverterScreen(),
                      DrawerItem.currencyConverter,
                      forcePush: true,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedIdea01,
                    title: 'How to use',
                    isSelected: widget.selectedItem == DrawerItem.howToUse,
                    onTap: () => _handleNav(
                      context,
                      const HowToUseScreen(),
                      DrawerItem.howToUse,
                      forcePush: true,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedAiChat01,
                    title: 'Feedback',
                    isSelected: widget.selectedItem == DrawerItem.feedback,
                    onTap: () => _handleNav(
                      context,
                      const FeedbackScreen(),
                      DrawerItem.feedback,
                      forcePush: true,
                    ),
                  ),
                  _MinimalDrawerTile(
                    icon: HugeIcons.strokeRoundedSettings02,
                    title: 'Settings',
                    isSelected: widget.selectedItem == DrawerItem.settings,
                    onTap: () => _handleNav(
                      context,
                      const AppSettingsScreen(),
                      DrawerItem.settings,
                      forcePush: true,
                    ),
                  ),
                ],
              ),
            ),

            // 4. FOOTER (Team/User Section)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 1),
            ),
            const _UserProfileFooter(),
          ],
        ),
      ),
    );
  }

  void _handleNav(
    BuildContext context,
    Widget screen,
    DrawerItem item, {
    bool forcePush = false,
  }) {
    // 1. Close the drawer
    Navigator.pop(context);

    // 2. Check if we're already on this screen
    if (widget.selectedItem == item) {
      return;
    }

    // Special case for Home
    if (item == DrawerItem.home) {
      if (!widget.isRoot) {
        // If not at root, pop until we are back at the first route (Home)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      return;
    }

    // 3. Navigation Logic
    // If we are at ROOT (Home), update logic:
    //   - Should push the new screen.
    // If we are NOT at ROOT (e.g. at Accounts), update logic:
    //   - If target is another Top Level Screen: Replace current (Accounts) with Target (Reports)
    //   - If target is Secondary (Settings): Push Settings on top of Accounts.
    //   - Exception: "forcePush" means always push (for secondary screens).

    if (forcePush || widget.isRoot) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }
}

// --- NEW MINIMAL TILE (Matches Reference) ---
class _MinimalDrawerTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isSelected;

  const _MinimalDrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    // ignore: unused_element_parameter
    this.trailing,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2.0,
      ), // Spacing between items
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // If selected, show the light grey background seen in "Products"
        tileColor: isSelected
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: HugeIcon(
          icon: icon,
          size: 22,
          strokeWidth: 2,
          // Icons in reference are dark grey/outline
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

// --- USER PROFILE FOOTER (Matches "Team" Section) ---
class _UserProfileFooter extends StatelessWidget {
  const _UserProfileFooter();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  12,
                ), // Rounded square like "Team" icon
                color: colorScheme.primaryContainer,
                image: user?.photoURL != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(user!.photoURL!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user?.photoURL == null
                  ? Center(
                      child: Text(
                        (user?.name != null && user!.name.isNotEmpty)
                            ? user.name[0].toUpperCase()
                            : 'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Guest User',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "View Profile",
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),

            // Collapse Icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
