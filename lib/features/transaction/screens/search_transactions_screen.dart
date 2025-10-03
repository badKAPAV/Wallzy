import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() => _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  final _searchController = TextEditingController();
  List<TransactionModel> _searchResults = [];
  List<TransactionModel> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    // Get all transactions once for efficient searching.
    _allTransactions = Provider.of<TransactionProvider>(context, listen: false).transactions;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final results = _allTransactions.where((tx) {
      // Check description
      final descriptionMatch = tx.description.toLowerCase().contains(query);
      if (descriptionMatch) return true;

      // Check person
      final personMatch = tx.people?.any((person) => person.fullName.toLowerCase().contains(query)) ?? false;
      if (personMatch) return true;

      // Check tags
      final tagMatch = tx.tags?.any((tag) => tag.name.toLowerCase().contains(query)) ?? false;
      if (tagMatch) return true;

      return false;
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _showTransactionDetails(BuildContext context, TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by description, person, or tag...',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search by description, person, or tags.'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(child: Text('No results found for "${_searchController.text}"'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final tx = _searchResults[index];
        return TransactionListItem(
          transaction: tx,
          onTap: () => _showTransactionDetails(context, tx),
        );
      },
    );
  }
}