import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart';
import 'package:wallzy/features/transaction/screens/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/screens/transaction_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _platform = MethodChannel('com.example.wallzy/sms');
  
  late final ScrollController _scrollController;
  bool _isFabVisible = true;
  List<Map<String, dynamic>> _pendingSmsTransactions = [];

  String _selectedTimeframe = 'This Month';
  final List<String> _timeframeOptions = [
    'Today', 'Yesterday', 'This Week', 'Last Week', 'This Month', 'Last Month',
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _platform.setMethodCallHandler(_handleSms);
    _fetchPendingSmsTransactions();
    
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      if (direction == ScrollDirection.reverse && _isFabVisible) {
        setState(() => _isFabVisible = false);
      } else if (direction == ScrollDirection.forward && !_isFabVisible) {
        setState(() => _isFabVisible = true);
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.notification,
    ].request();

    if (!mounted) return;
    if (statuses[Permission.sms]!.isPermanentlyDenied || statuses[Permission.notification]!.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permissions are required. Please enable them in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
  }

  Future<void> _fetchPendingSmsTransactions() async {
    try {
      final String? jsonString =
          await _platform.invokeMethod('getPendingSmsTransactions');
      if (jsonString != null && mounted) {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        setState(() {
          _pendingSmsTransactions = decodedList.cast<Map<String, dynamic>>();
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get pending transactions: '${e.message}'.");
    }
  }

  Future<void> _handleSms(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final Map args = call.arguments;
      final String? id = args['id'];
      final String type = args['type'];
      final double amount = args['amount'];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Transaction Detected', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Text('We detected a new ${type.toLowerCase()} of ₹${amount.toStringAsFixed(2)}. Would you like to add it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToAddTransaction(
                    isExpense: type == 'expense',
                    amount: amount,
                    smsTransactionId: id);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      // Using a simple format for older dates
      return DateFormat('d MMM').format(dt);
    }
  }

  void _navigateToAddTransaction(
      {required bool isExpense, double? amount, String? smsTransactionId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          isExpense: isExpense,
          initialAmount: amount?.toStringAsFixed(2),
          initialDate: DateTime.now(),
          smsTransactionId: smsTransactionId,
        ),
      ),
    ).then((_) {
      _fetchPendingSmsTransactions();
    });
  }
  
  void _signOut(BuildContext context) {
    HapticFeedback.lightImpact();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.signOut();
  }
  
  void _showTimeframePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            ..._timeframeOptions.map((option) => ListTile(
              title: Text(option),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTimeframe = option);
                Navigator.pop(context);
              },
            )).toList(),
          ],
        );
      },
    );
  }

  void _showAddTransactionOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
              title: const Text('Add Expense'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _navigateToAddTransaction(isExpense: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
              title: const Text('Add Income'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _navigateToAddTransaction(isExpense: false);
              },
            ),
          ],
        );
      },
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionModel transaction) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }
  
  Map<String, List<TransactionModel>> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      String key;
      if (txDate.isAtSameMomentAs(today)) {
        key = 'Today';
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('d MMMM, yyyy').format(txDate);
      }
      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final transactions = transactionProvider.transactions;
    final groupedTransactions = _groupTransactionsByDate(transactions);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: Text("Hi, ${user?.name ?? ''}"),
            pinned: true,
            floating: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _signOut(context),
              ),
            ],
          ),
          if (_pendingSmsTransactions.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildPendingSmsSection(),
            ),
          SliverToBoxAdapter(
            child: _buildSummaryCard(transactionProvider),
          ),
          if (transactions.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          
          if (transactions.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onAdd: _showAddTransactionOptions),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dateKey = groupedTransactions.keys.elementAt(index);
                  final transactionsForDate = groupedTransactions[dateKey]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateHeader(title: dateKey),
                      ...transactionsForDate.map((tx) => TransactionListItem(
                        transaction: tx,
                        onTap: () => _showTransactionDetails(context, tx),
                      )).toList(),
                    ],
                  );
                },
                childCount: groupedTransactions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 200)), // Extra space at bottom
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isFabVisible
            ? FloatingActionButton(
                onPressed: _showAddTransactionOptions,
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
  
  Widget _buildSummaryCard(TransactionProvider txProvider) {
    double income = 0;
    double expense = 0;

    switch (_selectedTimeframe) {
      case 'Today': income = txProvider.todayIncome; expense = txProvider.todayExpense; break;
      case 'Yesterday': income = txProvider.yesterdayIncome; expense = txProvider.yesterdayExpense; break;
      case 'This Week': income = txProvider.thisWeekIncome; expense = txProvider.thisWeekExpense; break;
      case 'Last Week': income = txProvider.lastWeekIncome; expense = txProvider.lastWeekExpense; break;
      case 'This Month': income = txProvider.thisMonthIncome; expense = txProvider.thisMonthExpense; break;
      case 'Last Month': income = txProvider.lastMonthIncome; expense = txProvider.lastMonthExpense; break;
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final balance = income - expense;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ActionChip(
                  label: Text(_selectedTimeframe),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  onPressed: _showTimeframePicker,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Balance', style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color)),
            Text(
              currencyFormat.format(balance),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.greenAccent : Colors.redAccent),
            ),
            const SizedBox(height: 16),
            
            // --- CHANGED: Using the new stacked progress bar ---
            _buildStackedProgressBar(income, expense),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryColumn(icon: Icons.arrow_downward, title: 'Income', amount: currencyFormat.format(income), color: Colors.greenAccent),
                _SummaryColumn(icon: Icons.arrow_upward, title: 'Expense', amount: currencyFormat.format(expense), color: Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSmsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected From SMS',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingSmsTransactions.length,
            itemBuilder: (context, index) {
              final pendingTx = _pendingSmsTransactions[index];
              final type = pendingTx['type'] as String;
              final amount = pendingTx['amount'] as num;
              // Use null-aware casting with a default value to prevent crashes from old data.
              final timestamp = pendingTx['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
              // Use -1 as a default, which is handled as an invalid ID on the native side.
              final notificationId = pendingTx['notificationId'] as int? ?? -1;
              final isExpense = type == 'expense';

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isExpense ? Colors.redAccent : Colors.green,
                  ),
                  title: Text(
                    NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isExpense ? 'Spent' : 'Received'),
                  trailing: Text(_formatTimestamp(timestamp)),
                  onTap: () async {
                    try {
                      await _platform.invokeMethod('cancelNotification', {'notificationId': notificationId});
                    } on PlatformException catch (e) {
                      debugPrint("Failed to cancel notification: '${e.message}'.");
                    }
                    _navigateToAddTransaction(
                      isExpense: isExpense,
                      amount: amount.toDouble(),
                      smsTransactionId: pendingTx['id'] as String,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // --- NEW: Helper widget for the stacked progress bar ---
  Widget _buildStackedProgressBar(double income, double expense) {
    final total = income + expense;

    if (total == 0) {
      // Show a neutral bar if there's no activity
      return Container(
        height: 20,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 20,
        child: Row(
          children: [
            Expanded(
              flex: income.round(),
              child: Container(color: Colors.greenAccent.withOpacity(0.5)),
            ),
            Expanded(
              flex: expense.round(),
              child: Container(color: Colors.redAccent.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Supporting Widgets (can be kept in the same file or moved) ---

class _SummaryColumn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final Color color;

  const _SummaryColumn({required this.icon, required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String title;
  const _DateHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No transactions yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Your transaction story starts here.', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add First Transaction'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

Widget _buildDragHandle() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}