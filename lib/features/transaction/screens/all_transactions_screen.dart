import 'package:flutter/material.dart';
import 'package:wallzy/features/transaction/widgets/categories_tab_screen.dart';
import 'package:wallzy/features/transaction/widgets/people_tab_screen.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Reports & Transactions'),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          indicatorWeight: 5,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, // indicator color
            borderRadius: BorderRadius.circular(25), // rounded edges
          ),
          indicatorPadding: EdgeInsets.fromLTRB(55, 45, 55, 0),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
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
            Tab(text: 'People'),
          ],
        ),
        actions: [
          IconButton(onPressed: (){}, icon: Icon(Icons.search_rounded, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant))
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TransactionsTabScreen(),
          CategoriesTabScreen(),
          PeopleTabScreen(),
        ],
      ),
    );
  }
}
