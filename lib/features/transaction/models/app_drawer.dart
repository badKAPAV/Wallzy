import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/screens/accounts_screen.dart';
import 'package:wallzy/features/subscription/screens/subscriptions_screen.dart';
import 'package:wallzy/features/transaction/models/user_profile_screen.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _signOut(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
            },
            child: UserAccountsDrawerHeader(
              accountName: Text(
                user?.name ?? 'Guest',
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
              accountEmail: Text(
                user?.email ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: Text(
                  user?.name.substring(0, 1).toUpperCase() ?? 'G',
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
            ),
          ),
          _DrawerItem(
            icon: Icons.bar_chart_rounded,
            title: 'Reports',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AllTransactionsScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Accounts',
            onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.sync_alt_rounded,
            title: 'Subscriptions',
            onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
            },
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}