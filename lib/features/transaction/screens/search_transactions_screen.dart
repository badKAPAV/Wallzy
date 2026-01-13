import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() =>
      _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  final _searchController = TextEditingController();
  List<TransactionModel> _searchResults = [];
  List<TransactionModel> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    // Get all transactions once for efficient searching.
    _allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
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
      final personMatch =
          tx.people?.any(
            (person) => person.fullName.toLowerCase().contains(query),
          ) ??
          false;
      if (personMatch) return true;

      // Check tags
      final tagMatch =
          tx.tags?.any((tag) => tag.name.toLowerCase().contains(query)) ??
          false;
      if (tagMatch) return true;

      return false;
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
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
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        titleSpacing: 12,
        title: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search for transactions',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(100),
                    ),
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.normal,
                    fontFamily: 'inter',
                    fontSize: 16,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _searchController.clear(),
                ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.isEmpty) {
      return EmptyReportPlaceholder(
        message: 'Search by description, person or folders',
        icon: HugeIcons.strokeRoundedSearchList02,
      );
    }

    if (_searchResults.isEmpty) {
      return EmptyReportPlaceholder(
        message: 'No results found for "${_searchController.text}"',
        icon: HugeIcons.strokeRoundedSearchRemove,
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
          ), // GroupedTransactionList has internal padding for headers
          sliver: GroupedTransactionList(
            transactions: _searchResults,
            onTap: (tx) => _showTransactionDetails(context, tx),
            useSliver: true,
          ),
        ),
      ],
    );
  }
}
