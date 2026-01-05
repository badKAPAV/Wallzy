import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/screens/subscription_details_screen.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class AllRecurringPaymentsScreen extends StatefulWidget {
  const AllRecurringPaymentsScreen({super.key});

  @override
  State<AllRecurringPaymentsScreen> createState() =>
      _AllRecurringPaymentsScreenState();
}

class _AllRecurringPaymentsScreenState
    extends State<AllRecurringPaymentsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Subscription> _filteredSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final theme = Theme.of(context);

    // Filter logic
    final allSubs = subProvider.subscriptions; // Assuming this returns all
    // If provider filters by isActive, we might need a getter for 'all' including archived if desired.
    // Provider code showed: get subscriptions => _subscriptions.where((s) => s.isActive).toList();
    // Use _subscriptions via a new getter if needed, but for now let's stick to public API.
    // User asked for "Active and Inactive tagged properly".
    // If "Inactive" means "Paused", they are active=true in model but pauseState != active.
    // If "Inactive" means "Archived" (isActive=false), we might need to expose them.
    // Provider's public getter filters `isActive`. Accessing private _subscriptions isn't possible directly.
    // I will assume for now "Active/Inactive" refers to Pause State, or I'll need to update provider.
    // Let's stick to what's available. If user meant Archived, we'd need a provider update.
    // Given "tagged properly", likely Active vs Paused.

    final query = _searchController.text.toLowerCase();
    _filteredSubscriptions = allSubs.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search payments...',
                  border: InputBorder.none,
                ),
              )
            : const Text('All Recurring Payments'),
        actions: [
          IconButton.filledTonal(
            icon: HugeIcon(
              icon: _isSearching
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 18,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _filteredSubscriptions.isEmpty
          ? EmptyReportPlaceholder(
              message: 'Oops! Nothing found...',
              icon: HugeIcons.strokeRoundedUmbrella,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredSubscriptions.length,
              itemBuilder: (context, index) {
                final sub = _filteredSubscriptions[index];
                return _SubscriptionListTile(sub: sub, txProvider: txProvider);
              },
            ),
    );
  }
}

class _SubscriptionListTile extends StatelessWidget {
  final Subscription sub;
  final TransactionProvider txProvider;

  const _SubscriptionListTile({required this.sub, required this.txProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaused = sub.pauseState != SubscriptionPauseState.active;

    // Get relevant transactions for details
    final txs = txProvider.transactions
        .where((tx) => tx.subscriptionId == sub.id)
        .toList();
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubscriptionDetailsScreen(
                subscription: sub,
                transactions: txs,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPaused
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_alt,
                  color: isPaused
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub.category,
                      style: TextStyle(
                        color: theme.colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaused ? "PAUSED" : "ACTIVE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPaused
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${sub.amount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
