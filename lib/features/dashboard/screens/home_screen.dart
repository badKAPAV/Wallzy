import 'dart:convert';
import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _platform = MethodChannel('com.example.wallzy/sms');

  late final ScrollController _scrollController;
  // bool _isFabVisible = true;
  bool _isFabExtended = true;
  List<Map<String, dynamic>> _pendingSmsTransactions = [];

  String _selectedTimeframe = 'This Month';
  final List<String> _timeframeOptions = [
    'Today',
    'Yesterday',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
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
      final atEdge = _scrollController.position.atEdge;
      if (direction == ScrollDirection.reverse && _isFabExtended) {
        setState(() {
          // _isFabVisible = false;
          _isFabExtended = false;
        });
      } else if (direction == ScrollDirection.forward && !_isFabExtended) {
        setState(() {
          // _isFabVisible = true;
          _isFabExtended = true;
        });
      }
      if (atEdge && direction == ScrollDirection.forward) {
        setState(() => _isFabExtended = true);
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
    if (statuses[Permission.sms]!.isPermanentlyDenied ||
        statuses[Permission.notification]!.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Permissions are required. Please enable them in settings.',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
  }

  Future<void> _fetchPendingSmsTransactions() async {
    try {
      final String? jsonString = await _platform.invokeMethod(
        'getPendingSmsTransactions',
      );
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
      final String? paymentMethod = args['paymentMethod'];
      final String? bankName = args['bankName'];
      final String? accountNumber = args['accountNumber'];
      final String? payee = args['payee'];
      final String? category = args['category'];

      if (!mounted) return;
      _navigateToAddTransaction(
        isExpense: type == 'expense',
        amount: amount,
        smsTransactionId: id,
        paymentMethod: paymentMethod,
        bankName: bankName,
        accountNumber: accountNumber,
        payee: payee,
        category: category,
      );
    } else if (call.method == 'newPendingSmsAvailable') {
      // This is called when the app is in the foreground and a new SMS is processed.
      debugPrint("New pending SMS available, refreshing list...");
      await _fetchPendingSmsTransactions();
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

  void _navigateToAddTransaction({
    required bool isExpense,
    double? amount,
    String? smsTransactionId,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? payee,
    String? category,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          isExpense: isExpense,
          initialAmount: amount?.toStringAsFixed(2),
          initialPaymentMethod: paymentMethod,
          initialDate: DateTime.now(),
          smsTransactionId: smsTransactionId,
          initialBankName: bankName,
          initialAccountNumber: accountNumber,
          initialPayee: payee,
          initialCategory: category,
        ),
      ),
    ).then((_) {
      _fetchPendingSmsTransactions();
    });
  }

  Future<bool> _showDismissConfirmationDialog(Map<String, dynamic> tx) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Suggestion?'),
        content: const Text(
          'This will remove the transaction suggestion. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final id = tx['id'] as String;
        final notificationId = tx['notificationId'] as int? ?? -1;
        await _platform.invokeMethod('removePendingSmsTransaction', {'id': id});
        await _platform.invokeMethod('cancelNotification', {
          'notificationId': notificationId,
        });
        if (mounted) {
          setState(() {
            _pendingSmsTransactions.removeWhere((item) => item['id'] == id);
          });
        }
      } on PlatformException catch (e) {
        debugPrint("Failed to dismiss transaction: '${e.message}'.");
        return false; // Prevent dismissal on failure
      }
      return true;
    }
    return false;
  }

  Future<void> _showDismissAllConfirmationDialog() async {
    if (_pendingSmsTransactions.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss All Suggestions?'),
        content: Text(
          'This will remove all ${_pendingSmsTransactions.length} suggestions and their notifications. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: const Text('Dismiss All'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _platform.invokeMethod('removeAllPendingSmsTransactions');
        if (mounted) setState(() => _pendingSmsTransactions.clear());
      } on PlatformException catch (e) {
        debugPrint("Failed to dismiss all transactions: '${e.message}'.");
      }
    }
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
            ..._timeframeOptions
                .map(
                  (option) => ListTile(
                    title: Text(option),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedTimeframe = option);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ],
        );
      },
    );
  }

  void _showAddTransactionOptions() {
    final appColors = Theme.of(context).extension<AppColors>()!;
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
              leading: Icon(Icons.arrow_upward, color: appColors.expense),
              title: const Text('Add Expense'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _navigateToAddTransaction(isExpense: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.arrow_downward, color: appColors.income),
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

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
    List<TransactionModel> transactions,
  ) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
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
    final recentTransactions = transactionProvider.transactions
        .take(20)
        .toList();
    final groupedTransactions = _groupTransactionsByDate(recentTransactions);

    print('Container highest -> ${Theme.of(context).colorScheme.surfaceContainerHighest}');
    print('Container lowest -> ${Theme.of(context).colorScheme.surfaceContainerLowest}');
    print('surface tint -> ${Theme.of(context).colorScheme.surfaceTint}');
    print('surface dim -> ${Theme.of(context).colorScheme.surfaceDim}');
    print('surface -> ${Theme.of(context).colorScheme.surface}');
    print('============================');
    print('============================');

    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
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
          // 1. SUMMARY CARD IS NOW THE FIRST ITEM
          SliverToBoxAdapter(child: _buildSummaryCard(transactionProvider)),
          // 2. SMS SECTION IS SECOND
          if (_pendingSmsTransactions.isNotEmpty)
            SliverToBoxAdapter(child: _buildPendingSmsSection()),

          if (recentTransactions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 8.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllTransactionsScreen(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (recentTransactions.isEmpty && _pendingSmsTransactions.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onAdd: _showAddTransactionOptions),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final dateKey = groupedTransactions.keys.elementAt(index);
                final transactionsForDate = groupedTransactions[dateKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateHeader(title: dateKey),
                    ...transactionsForDate
                        .map(
                          (tx) => TransactionListItem(
                            transaction: tx,
                            onTap: () => _showTransactionDetails(context, tx),
                          ),
                        )
                        .toList()
                        .animate(interval: 50.ms) // 3. STAGGERED LIST ANIMATION
                        .fade(duration: 200.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.2),
                  ],
                );
              }, childCount: groupedTransactions.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      // 4. NEW EXTENDED FLOATING ACTION BUTTON
      floatingActionButton: _buildMorphingFab(),
    );
  }

  Widget _buildMorphingFab() {
    final theme = Theme.of(context);

    // Define the properties for both extended and compact states
    const double fabHeight = 56.0;
    const double compactWidth = 56.0;
    const double extendedWidth = 190.0;
    final compactBorderRadius = BorderRadius.circular(fabHeight / 4);
    final extendedBorderRadius = BorderRadius.circular(16);

    return SizedBox(
      height: fabHeight,
      child: GestureDetector(
        onTap: _showAddTransactionOptions,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: _isFabExtended ? extendedWidth : compactWidth,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: _isFabExtended
                ? extendedBorderRadius
                : compactBorderRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: theme.colorScheme.onPrimary),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: _isFabExtended
                    ? Padding(
                        key: const ValueKey("label"),
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          "New Transaction",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey("empty")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TransactionProvider txProvider) {
    double income = 0;
    double expense = 0;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    switch (_selectedTimeframe) {
      case 'Today':
        income = txProvider.todayIncome;
        expense = txProvider.todayExpense;
        break;
      case 'Yesterday':
        income = txProvider.yesterdayIncome;
        expense = txProvider.yesterdayExpense;
        break;
      case 'This Week':
        income = txProvider.thisWeekIncome;
        expense = txProvider.thisWeekExpense;
        break;
      case 'Last Week':
        income = txProvider.lastWeekIncome;
        expense = txProvider.lastWeekExpense;
        break;
      case 'This Month':
        income = txProvider.thisMonthIncome;
        expense = txProvider.thisMonthExpense;
        break;
      case 'Last Month':
        income = txProvider.lastMonthIncome;
        expense = txProvider.lastMonthExpense;
        break;
    }

    final monthMap = {
      "1": "January",
      "2": "February",
      "3": "March",
      "4": "April",
      "5": "May",
      "6": "June",
      "7": "July",
      "8": "August",
      "9": "September",
      "10": "October",
      "11": "November",
      "12": "December",
    };

    final now = DateTime.now().month;
    final currentMonth = monthMap[now.toString()];

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final balance = income - expense;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTransactionsScreen()),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(16),
        // Using `surface` for the main card and `surfaceDim` for the scaffold background
        // creates a consistent and noticeable elevation effect.
        color: colorScheme.primary.withAlpha(30),
        // 5. EXPRESSIVE SHAPE
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(currentMonth!, style: textTheme.titleLarge),
                  // ActionChip(
                  //   label: Text(_selectedTimeframe),
                  //   avatar: const Icon(Icons.calendar_today, size: 16),
                  //   onPressed: _showTimeframePicker,
                  // ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Balance',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              // 6. ANIMATED SWITCHER FOR BALANCE
              AnimatedSwitcher(
                duration: 500.ms,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  key: ValueKey<String>("${_selectedTimeframe}_$balance"),
                  currencyFormat.format(balance),
                  style: textTheme.displayLarge?.copyWith(
                    color: balance >= 0 ? appColors.income : appColors.expense,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 7. IMPROVED PROPORTIONAL PROGRESS BAR
              _buildStackedProgressBar(income, expense, appColors),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SummaryColumn(
                    icon: Icons.arrow_downward,
                    title: 'Income',
                    amount: currencyFormat.format(income),
                    color: appColors.income,
                  ),
                  _SummaryColumn(
                    icon: Icons.arrow_upward,
                    title: 'Expense',
                    amount: currencyFormat.format(expense),
                    color: appColors.expense,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSmsSection() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected from SMS (${_pendingSmsTransactions.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _showDismissAllConfirmationDialog,
                  child: const Text('Dismiss All'),
                ),
              ],
            ),
          ),
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingSmsTransactions.length,
            itemBuilder: (context, index) {
              final pendingTx = _pendingSmsTransactions[index];
              final type = pendingTx['type'] as String;
              final amount = pendingTx['amount'] as num;
              final paymentMethod = pendingTx['paymentMethod'] as String?;
              final timestamp =
                  pendingTx['timestamp'] as int? ??
                  DateTime.now().millisecondsSinceEpoch;
              final notificationId = pendingTx['notificationId'] as int? ?? -1;
              final isExpense = type == 'expense';
              final bankName = pendingTx['bankName'] as String?;
              final accountNumber = pendingTx['accountNumber'] as String?;
              final payee = pendingTx['payee'] as String?;
              final category = pendingTx['category'] as String?;

              return Dismissible(
                key: ValueKey(pendingTx['id']),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) =>
                    _showDismissConfirmationDialog(pendingTx),
                background: Container(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.white,
                  ),
                ),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: ListTile(
                    leading: Icon(
                      isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isExpense ? appColors.expense : appColors.income,
                    ),
                    title: Text(
                      NumberFormat.currency(
                        symbol: '₹',
                        decimalDigits: 2,
                      ).format(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Builder(
                      builder: (context) {
                        String subtitleText;
                        if (payee != null) {
                          subtitleText = isExpense
                              ? 'To $payee'
                              : 'From $payee';
                          if (bankName != null) {
                            subtitleText += ' • $bankName';
                          }
                        } else if (paymentMethod != null) {
                          subtitleText = 'Via $paymentMethod';
                        } else {
                          subtitleText = isExpense ? 'Spent' : 'Received';
                        }
                        return Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    trailing: Text(_formatTimestamp(timestamp)),
                    onTap: () async {
                      try {
                        await _platform.invokeMethod('cancelNotification', {
                          'notificationId': notificationId,
                        });
                      } on PlatformException catch (e) {
                        debugPrint(
                          "Failed to cancel notification: '${e.message}'.",
                        );
                      }
                      _navigateToAddTransaction(
                        isExpense: isExpense,
                        amount: amount.toDouble(),
                        smsTransactionId: pendingTx['id'] as String,
                        paymentMethod: paymentMethod,
                        bankName: bankName,
                        accountNumber: accountNumber,
                        payee: payee,
                        category: category,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- NEW: Helper widget for the stacked progress bar ---
  Widget _buildStackedProgressBar(
    double income,
    double expense,
    AppColors appColors,
  ) {
    final total = income + expense;

    if (total == 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final incomePercent = income / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Expanded(
              flex: (incomePercent * 100).round(),
              child: Container(color: appColors.income),
            ),
            Expanded(
              flex: ((1 - incomePercent) * 100).round(),
              child: Container(color: appColors.expense),
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

  const _SummaryColumn({
    required this.icon,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
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
          const Text(
            'No transactions yet.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction story starts here.',
            style: TextStyle(color: Colors.grey[600]),
          ),
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
