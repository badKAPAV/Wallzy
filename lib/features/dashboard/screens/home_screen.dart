import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/transaction/models/app_drawer.dart';
import 'package:wallzy/features/subscription/models/due_subscription.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_list_item.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';

// A data model for the mini-chart in the summary card
class _PeriodSummary {
  final String label;
  final double income;
  final double expense;

  _PeriodSummary({
    required this.label,
    required this.income,
    required this.expense,
  });
}

enum Timeframe { week, month, year }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _platform = MethodChannel('com.example.wallzy/sms');
  static const _dueSubPrefsKey = 'due_subscription_suggestions';

  late final ScrollController _scrollController;
  late final TabController _actionCenterTabController;
  bool _isFabExtended = true;
  List<DueSubscription> _dueSubscriptions = [];
  List<Map<String, dynamic>> _pendingSmsTransactions = [];

  bool _isProcessingSms = false;
  // New state for the interactive summary card
  
  Timeframe _selectedTimeframe = Timeframe.month;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _platform.setMethodCallHandler(_handleSms);
    WidgetsBinding.instance.addObserver(this);

    // On startup, check if the app was launched by a notification intent.
    _processLaunchData();

    _actionCenterTabController = TabController(length: 2, vsync: this);
    _fetchPendingSmsTransactions();
    _loadDueSubscriptions();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      final atEdge = _scrollController.position.atEdge;
      if (direction == ScrollDirection.reverse && _isFabExtended) {
        setState(() => _isFabExtended = false);
      } else if (direction == ScrollDirection.forward && !_isFabExtended) {
        setState(() => _isFabExtended = true);
      }
      if (atEdge && direction == ScrollDirection.forward) {
        setState(() => _isFabExtended = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actionCenterTabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh pending lists when app comes to foreground
      _fetchPendingSmsTransactions();
      _loadDueSubscriptions();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
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

  Future<void> _loadDueSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_dueSubPrefsKey);
    if (jsonString != null && mounted) {
      final List<dynamic> decodedList = jsonDecode(jsonString);
      setState(() {
        _dueSubscriptions =
            decodedList.map((data) => DueSubscription.fromMap(data)).toList();
      });
    }
  }

  Future<void> _saveDueSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dueSubPrefsKey, jsonEncode(_dueSubscriptions.map((e) => e.toMap()).toList()));
  }

  // Pulls data if the app was launched from a terminated state by a notification.
  Future<void> _processLaunchData() async {
    try {
      final String? jsonString = await _platform.invokeMethod('getLaunchData');
      if (jsonString != null) {
        debugPrint("[HomeScreen] _processLaunchData (PULL) received: $jsonString");
        final Map<String, dynamic> args = jsonDecode(jsonString);
        _navigateToTransactionFromData(args);
      } else {
        debugPrint("[HomeScreen] _processLaunchData: No launch data found.");
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get launch data: '${e.message}'.");
    }
  }

  Future<void> _handleSms(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      // This handles the PUSH case when the app is already running.
      debugPrint("[HomeScreen] _handleSms (PUSH) received: ${call.arguments}");
      final Map args = call.arguments;
      _navigateToTransactionFromData(args.cast<String, dynamic>());
    } else if (call.method == 'newPendingSmsAvailable') {
      // This is called when the app is in the foreground and a new SMS is processed.
      debugPrint("New pending SMS available, refreshing list...");
      await _fetchPendingSmsTransactions();
    }
  }

  // Centralized logic to navigate to the AddTransactionScreen from SMS data.
  Future<void> _navigateToTransactionFromData(Map<String, dynamic> args) async {
    setState(() => _isProcessingSms = true);

    try {
      // This is our readiness check. We try to get account data, which requires
      // a network connection on a cold start. We'll timeout if it takes too long.
      await Provider.of<AccountProvider>(context, listen: false)
          .getPrimaryAccount()
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final String? id = args['id'];
      final String type = args['type'];
      final double amount = (args['amount'] as num).toDouble();
      final String? paymentMethod = args['paymentMethod'];
      final String? bankName = args['bankName'];
      final String? accountNumber = args['accountNumber'];
      final String? payee = args['payee'];
      final String? category = args['category'];

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
    } catch (e) {
      debugPrint("Failed to process SMS transaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection failed. The suggestion has been saved in the Action Center.')),
        );
        // Refresh the list to show the suggestion that failed to process.
        _fetchPendingSmsTransactions();
      }
    } finally {
      if (mounted) setState(() => _isProcessingSms = false);
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
    // Add log here to see what is being passed to the next screen
    debugPrint("[HomeScreen] Navigating to AddTransactionScreen with: payee=$payee, bankName=$bankName, accountNumber=$accountNumber");

    // This is for SMS-based transactions
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

  void _navigateToAddSubscriptionTransaction(DueSubscription suggestion) {
    // This is for due subscription suggestions
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          isExpense: true, // Subscriptions are always expenses
          initialAmount: suggestion.averageAmount.toStringAsFixed(2),
          initialPaymentMethod: suggestion.lastPaymentMethod,
          initialDate: suggestion.dueDate,
          initialPayee: suggestion.subscriptionName, // Use name as payee/desc
          initialCategory: suggestion.lastCategory,
        ),
      ),
    ).then((_) {
      // After adding, we assume it's handled, so we remove it.
      _removeDueSubscription(suggestion);
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

  Future<void> _removeDueSubscription(DueSubscription suggestion) async {
    setState(() {
      _dueSubscriptions.removeWhere((s) => s.id == suggestion.id);
    });
    await _saveDueSubscriptions();
  }

  Future<bool> _showDismissDueSubscriptionDialog(DueSubscription suggestion) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Suggestion?'),
        content: const Text(
          'This will remove the subscription suggestion for this period. It may appear again on its next due date.',
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
      await _removeDueSubscription(suggestion);
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
        .take(10)
        .toList();
    final groupedTransactions = _groupTransactionsByDate(recentTransactions);

    // print('Container highest -> ${Theme.of(context).colorScheme.surfaceContainerHighest}');
    // print('Container lowest -> ${Theme.of(context).colorScheme.surfaceContainerLowest}');
    // print('surface tint -> ${Theme.of(context).colorScheme.surfaceTint}');
    // print('surface dim -> ${Theme.of(context).colorScheme.surfaceDim}');
    // print('surface -> ${Theme.of(context).colorScheme.surface}');
    // print('============================');
    // print('============================');

    return Scaffold(
      drawer: _isProcessingSms ? null : const AppDrawer(),
      // backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: Text("${_getGreeting()}, ${user?.name ?? ''}"),
            pinned: true,
            floating: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchTransactionsScreen()),
                  );
                },
              ),
            ],
          ),
          // 1. SUPERCHARGED SUMMARY CARD
          SliverToBoxAdapter(
              child: _buildSuperSummaryCard(transactionProvider)),

          // 2. ACTION CENTER
          _buildActionCenter(),

          // 3. SPENDING INSIGHTS
          SliverToBoxAdapter(
            child: _buildSpendingInsightsCard(transactionProvider),
          ),

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

          if (recentTransactions.isEmpty &&
              _pendingSmsTransactions.isEmpty &&
              _dueSubscriptions.isEmpty)
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
      floatingActionButton: Stack(
        children: [
          _buildMorphingFab(),
          if (_isProcessingSms)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
      // floatingActionButton: _isProcessingSms
      //     ? const CircularProgressIndicator()
      //     : _buildMorphingFab(),
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

  Widget _buildSuperSummaryCard(TransactionProvider txProvider) {
    final range = _getFilterRangeForTimeframe(_selectedTimeframe);
    final income = txProvider.getTotal(start: range.start, end: range.end, type: 'income');
    final expense = txProvider.getTotal(start: range.start, end: range.end, type: 'expense');
    final previousPeriodExpense = _getPreviousPeriodExpense(txProvider, _selectedTimeframe);
    final balance = income - expense;
    final chartSummaries = _getChartSummaries(txProvider, _selectedTimeframe);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildCustomTimeframeSelector()),
            const SizedBox(height: 20),
            Center(child: _BalanceDisplay(balance: balance, previousPeriodExpense: previousPeriodExpense, expense: expense)),
            const SizedBox(height: 20),
            if (chartSummaries.isNotEmpty)
              _MiniBarChart(summaries: chartSummaries),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTimeframeSelector() {
    const double selectorWidth = 250;
    const double selectorHeight = 40;
    final double buttonWidth = selectorWidth / 3;

    return Container(
      width: selectorWidth,
      height: selectorHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: _selectedTimeframe.index * buttonWidth,
            child: Container(
              width: buttonWidth,
              height: selectorHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Row(
            children: Timeframe.values.map((timeframe) {
              final isSelected = _selectedTimeframe == timeframe;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedTimeframe = timeframe);
                  },
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: Text(timeframe.name[0].toUpperCase() + timeframe.name.substring(1)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCenter() {
    final hasSms = _pendingSmsTransactions.isNotEmpty;
    final hasSubs = _dueSubscriptions.isNotEmpty;

    if (!hasSms && !hasSubs) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Action Center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TabBar(
              controller: _actionCenterTabController,
              unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withAlpha(150),
              tabs: [
                Tab(text: 'From SMS (${_pendingSmsTransactions.length})'),
                Tab(text: 'Due Subscriptions (${_dueSubscriptions.length})'),
              ],
            ),
            SizedBox(
              height: 240, // Adjust height as needed, or calculate dynamically
              child: TabBarView(
                controller: _actionCenterTabController,
                children: [
                  _buildSmsSuggestionsList(),
                  _buildDueSubscriptionsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingInsightsCard(TransactionProvider txProvider) {
    final range = _getFilterRangeForTimeframe(_selectedTimeframe);
    final periodTransactions = txProvider.transactions
        .where((tx) => tx.timestamp.isAfter(range.start) &&
            tx.timestamp.isBefore(range.end) &&
            tx.type == 'expense' &&
            tx.purchaseType == 'debit' && // Only 'real' expenses for spending analysis
            tx.category != 'Credit Repayment') // Exclude repayments
        .toList();

    if (periodTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, double> spentByCategory = {};
    for (var tx in periodTransactions) {
      spentByCategory.update(tx.category, (value) => value + tx.amount,
          ifAbsent: () => tx.amount);
    }

    final categorySummaries = spentByCategory.entries
        .map((entry) =>
            (name: entry.key, amount: entry.value))
        .toList();
    categorySummaries.sort((a, b) => b.amount.compareTo(a.amount));

    final totalSpent = categorySummaries.fold<double>(0.0, (sum, s) => sum + s.amount);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllTransactionsScreen())),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Spending Breakdown', style: Theme.of(context).textTheme.titleLarge),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16,)
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: _SpendingPieChart(summaries: categorySummaries, totalAmount: totalSpent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmsSuggestionsList() {
    if (_pendingSmsTransactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No new SMS suggestions.'),
        ),
      );
    }

    final appColors = Theme.of(context).extension<AppColors>()!;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showDismissAllConfirmationDialog,
            child: const Text('Dismiss All'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            itemCount: _pendingSmsTransactions.length,
            itemBuilder: (context, index) {
              final pendingTx = _pendingSmsTransactions[index];
              final type = pendingTx['type'] as String;
              final amount = pendingTx['amount'] as num;
              final paymentMethod = pendingTx['paymentMethod'] as String?;
              final timestamp = pendingTx['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
              final notificationId = pendingTx['notificationId'] as int? ?? -1;
              final isExpense = type == 'expense';
              final bankName = pendingTx['bankName'] as String?;
              final accountNumber = pendingTx['accountNumber'] as String?;
              final payee = pendingTx['payee'] as String?;
              final category = pendingTx['category'] as String?;

              return Dismissible(
                key: ValueKey(pendingTx['id']),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) => _showDismissConfirmationDialog(pendingTx),
                background: Container(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                ),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isExpense ? appColors.expense : appColors.income,
                    ),
                    title: Text(
                      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Builder(
                      builder: (context) {
                        String subtitleText;
                        if (payee != null) {
                          subtitleText = isExpense ? 'To $payee' : 'From $payee';
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
                        await _platform.invokeMethod('cancelNotification', {'notificationId': notificationId});
                      } on PlatformException catch (e) {
                        debugPrint("Failed to cancel notification: '${e.message}'.");
                      }
                        _navigateToTransactionFromData(pendingTx);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDueSubscriptionsList() {
    if (_dueSubscriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No subscriptions are due.'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: _dueSubscriptions.length,
      itemBuilder: (context, index) {
        final suggestion = _dueSubscriptions[index];
        final amount = suggestion.averageAmount;

        return Dismissible(
          key: ValueKey(suggestion.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) => _showDismissDueSubscriptionDialog(suggestion),
          background: Container(
            color: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          ),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.sync_problem_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(
                suggestion.subscriptionName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '~${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount)} was due on ${DateFormat.yMMMd().format(suggestion.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                _navigateToAddSubscriptionTransaction(suggestion);
              },
            ),
          ),
        );
      },
    );
  }

  DateTimeRange _getFilterRangeForTimeframe(Timeframe timeframe) {
    final now = DateTime.now();
    switch (timeframe) {
      case Timeframe.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day), end: now.add(const Duration(days: 1)));
      case Timeframe.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now.add(const Duration(days: 1)));
      case Timeframe.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now.add(const Duration(days: 1)));
    }
  }

  double _getPreviousPeriodExpense(TransactionProvider txProvider, Timeframe timeframe) {
    final now = DateTime.now();
    DateTimeRange prevRange;
    switch (timeframe) {
      case Timeframe.week:
        final startOfThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        prevRange = DateTimeRange(start: startOfLastWeek, end: startOfThisWeek);
        break;
      case Timeframe.month:
        final startOfThisMonth = DateTime(now.year, now.month, 1);
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        prevRange = DateTimeRange(start: startOfLastMonth, end: startOfThisMonth);
        break;
      case Timeframe.year:
        final startOfThisYear = DateTime(now.year, 1, 1);
        final startOfLastYear = DateTime(now.year - 1, 1, 1);
        prevRange = DateTimeRange(start: startOfLastYear, end: startOfThisYear);
        break;
    }
    return txProvider.getTotal(start: prevRange.start, end: prevRange.end, type: 'expense');
  }

  List<_PeriodSummary> _getChartSummaries(TransactionProvider txProvider, Timeframe timeframe) {
    final now = DateTime.now();
    List<_PeriodSummary> summaries = [];

    for (int i = 2; i >= 0; i--) {
      DateTimeRange range;
      String label;

      switch (timeframe) {
        case Timeframe.week:
          final startDay = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
          range = DateTimeRange(start: startDay, end: startDay.add(const Duration(days: 7)));
          label = DateFormat('d MMM').format(startDay);
          break;
        case Timeframe.month:
          final month = DateTime(now.year, now.month - i, 1);
          range = DateTimeRange(start: month, end: DateTime(month.year, month.month + 1, 1));
          label = DateFormat('MMM').format(month);
          break;
        case Timeframe.year:
          final year = DateTime(now.year - i, 1, 1);
          range = DateTimeRange(start: year, end: DateTime(year.year + 1, 1, 1));
          label = DateFormat('yyyy').format(year);
          break;
      }

      final income = txProvider.getTotal(start: range.start, end: range.end, type: 'income');
      final expense = txProvider.getTotal(start: range.start, end: range.end, type: 'expense');

      summaries.add(_PeriodSummary(label: label, income: income, expense: expense));
    }
    return summaries;
  }
}

// --- Supporting Widgets (can be kept in the same file or moved) ---

class _BalanceDisplay extends StatelessWidget {
  final double balance;
  final double previousPeriodExpense;
  final double expense;

  const _BalanceDisplay({
    required this.balance,
    required this.previousPeriodExpense,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    String comparisonText = '';
    Color? comparisonColor;

    if (previousPeriodExpense > 0) {
      final diff = expense - previousPeriodExpense;
      final percentChange = (diff / previousPeriodExpense * 100);
      if (percentChange.isFinite) {
        final sign = percentChange > 0 ? '+' : '';
        comparisonText = '${sign}${percentChange.toStringAsFixed(0)}% vs last period';
        comparisonColor = percentChange > 0 ? appColors.expense : appColors.income;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Balance',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(balance),
          style: textTheme.displayMedium?.copyWith(
            color: balance >= 0 ? appColors.income : appColors.expense,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (comparisonText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            comparisonText,
            style: textTheme.bodySmall?.copyWith(color: comparisonColor),
          ),
        ],
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<_PeriodSummary> summaries;
  const _MiniBarChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final maxAmount = summaries.fold<double>(
        0.0, (maxVal, s) => max(maxVal, max(s.income, s.expense)));

    return SizedBox(
      height: 80,
      child: BarChart(
        BarChartData(
          maxY: maxAmount == 0 ? 1 : maxAmount * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= summaries.length) return const SizedBox();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(summaries[index].label, style: Theme.of(context).textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(summaries.length, (index) {
            final summary = summaries[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(toY: summary.income, color: appColors.income, width: 8),
                BarChartRodData(toY: summary.expense, color: appColors.expense, width: 8),
              ],
              showingTooltipIndicators: [],
            );
          }),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

class _SpendingPieChart extends StatelessWidget {
  final List<({String name, double amount})> summaries;
  final double totalAmount;

  const _SpendingPieChart({required this.summaries, required this.totalAmount});

  Color _getColorForCategory(String category) {
    final hash = category.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(255, (r + 100) % 256, (g + 100) % 256, (b + 100) % 256);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final hasData = summaries.isNotEmpty && totalAmount > 0;

    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: hasData
                ? PieChart(
                    PieChartData(
                      sections: summaries.map((summary) {
                        return PieChartSectionData(
                          value: summary.amount,
                          color: _getColorForCategory(summary.name),
                          title: '',
                          radius: 50,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  )
                : const Center(child: Text("No spending data.")),
          ),
          const SizedBox(width: 30),
          Expanded(
            flex: 3,
            child: hasData
                ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: summaries.length > 5 ? 5 : summaries.length, // Show top 5
                    itemBuilder: (context, index) {
                      final summary = summaries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getColorForCategory(summary.name),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summary.name,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currencyFormat.format(summary.amount),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const SizedBox(),
          ),
        ],
      ),
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
    ));
}