import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/transaction/widgets/categories_tab_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_tab_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(
                fontWeight: FontWeight.normal,
                // color: Theme.of(context).colorScheme.primary,
              ),
          indicatorWeight: 5,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, // indicator color
            borderRadius: BorderRadius.circular(25), // rounded edges
          ),
          indicatorPadding: EdgeInsets.fromLTRB(0, 45, 0, 0),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          controller: _tabController,
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withAlpha(150),
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Categories'),
            // Tab(text: 'People'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SearchTransactionsScreen()),
              );
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TransactionsTabScreen(),
          CategoriesTabScreen(),
          // PeopleTabScreen(),
        ],
      ),
    );
  }
}
