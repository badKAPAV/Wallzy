import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/footer_graphic.dart';
import 'package:wallzy/common/widgets/messages_permission_banner.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/dashboard/widgets/home_widgets_section.dart';
import 'package:wallzy/features/dashboard/widgets/loading_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/features/dashboard/models/radial_menu_item_model.dart';
import 'package:wallzy/features/subscription/models/due_subscription.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/screens/pending_sms_screen.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:wallzy/features/dashboard/provider/home_widgets_provider.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';
import 'package:wallzy/features/people/screens/add_debt_loan_screen.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:uuid/uuid.dart';

// New Imports
import 'package:wallzy/features/dashboard/widgets/sliver_app_bar_widget.dart';
import 'package:wallzy/features/dashboard/widgets/action_deck_widget.dart';
import 'package:wallzy/features/dashboard/widgets/analytics_widget.dart';
import 'package:wallzy/features/dashboard/widgets/recent_activity_widget.dart';
import 'package:wallzy/features/dashboard/widgets/glass_radial_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  late final ScrollController _scrollController;
  bool _isFabExtended = true;
  final List<DueSubscription> _dueSubscriptions = [];
  final List<Map<String, dynamic>> _pendingSmsTransactions = [];

  final bool _isProcessingSms = false;
  bool _minLoadingFinished = false;
  Timeframe _selectedTimeframe = Timeframe.months;

  Timer? _titleTimer;

  bool _isAutoRecording = true;
  final ValueNotifier<int> _autoRecordTotal = ValueNotifier(0);
  final ValueNotifier<int> _autoRecordProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _minLoadingFinished = true;
        });
      }
    });

    _initConnectivityListener();
    _requestPermissions();
    _platform.setMethodCallHandler(_handleSms);
    WidgetsBinding.instance.addObserver(this);
    _processLaunchData();
    _loadDueSubscriptions();

    // Initialize HomeWidgets for the current user
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      Provider.of<HomeWidgetsProvider>(context, listen: false).init(user.uid);
    }

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

    _fetchPendingSmsTransactions().then((_) async {
      await _processAutoRecord();
      if (mounted) {
        setState(() {
          _isAutoRecording = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _processLaunchData();
      _fetchPendingSmsTransactions().then((_) => _processAutoRecord());
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void dispose() {
    _titleTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _autoRecordTotal.dispose();
    _autoRecordProgress.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _initConnectivityListener() {
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      final settingsProvider = context.read<SettingsProvider>();
      final isOffline = settingsProvider.isOffline;

      if (!hasConnection && !isOffline) {
        _switchToOfflineMode();
      } else if (hasConnection && isOffline) {
        _showBackOnlineSnackbar();
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (!hasConnection) {
      _switchToOfflineMode(showSnackbar: true);
    } else {
      await FirebaseFirestore.instance.enableNetwork();
      if (mounted) {
        context.read<SettingsProvider>().setOfflineStatus(false);
      }
    }
  }

  Future<void> _switchToOfflineMode({bool showSnackbar = true}) async {
    await FirebaseFirestore.instance.disableNetwork();
    if (!mounted) return;

    context.read<SettingsProvider>().setOfflineStatus(true);

    if (showSnackbar) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedWifiDisconnected01,
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                "Switching to offline mode",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showBackOnlineSnackbar() {
    final theme = Theme.of(context).colorScheme;

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Back online!", style: TextStyle(color: theme.onSurface)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        backgroundColor: theme.surfaceContainer,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: "Reload",
          textColor: theme.onSurface,
          backgroundColor: theme.surfaceContainerHigh,
          onPressed: () async {
            await FirebaseFirestore.instance.enableNetwork();
            if (mounted) {
              context.read<SettingsProvider>().setOfflineStatus(false);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),
        duration: const Duration(days: 1),
      ),
    );
  }

  void _handleDismissAllPending() async {
    final totalAmount = _pendingSmsTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + (tx['amount'] as num).toDouble(),
    );

    final settingsProvider = context.read<SettingsProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ignore All?"),
          content: Text(
            "Are you sure you want to ignore all pending transactions totaling ${settingsProvider.currencySymbol}${totalAmount.toStringAsFixed(0)}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text("Ignore All"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      for (var tx in _pendingSmsTransactions) {
        if (tx['id'] != null) {
          _platform.invokeMethod('removePendingSmsTransaction', {
            'id': tx['id'],
          });
        }
      }

      setState(() {
        _pendingSmsTransactions.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All pending transactions ignored")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    if (transactionProvider.isLoading ||
        authProvider.isAuthLoading ||
        !_minLoadingFinished ||
        _isAutoRecording ||
        !settingsProvider.isSettingsLoaded) {
      return LoadingScreen(
        isAutoRecording: _isAutoRecording,
        autoRecordTotal: _autoRecordTotal,
        autoRecordProgress: _autoRecordProgress,
      );
    }

    final recentTransactions = transactionProvider.transactions
        .take(8)
        .toList();

    return Scaffold(
      key: const ValueKey('main_dashboard'),
      drawer: _isProcessingSms ? null : const AppDrawer(isRoot: true),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. HERO HEADER
              HomeSliverAppBar(selectedTimeframe: _selectedTimeframe),

              // 2. ACTION DECK
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: MessagesPermissionBanner(),
                ),
              ),
              if (_pendingSmsTransactions.isNotEmpty ||
                  _dueSubscriptions.isNotEmpty)
                SliverToBoxAdapter(
                  child: ActionDeckWidget(
                    pendingSmsTransactions: _pendingSmsTransactions,
                    dueSubscriptions: _dueSubscriptions,
                    onPendingSmsTap: _navigateToTransactionFromData,
                    onPendingSmsDismiss: (tx) async {
                      await _platform.invokeMethod(
                        'removePendingSmsTransaction',
                        {'id': tx['id']},
                      );
                      setState(() {
                        _pendingSmsTransactions.removeWhere(
                          (e) => e['id'] == tx['id'],
                        );
                      });
                    },
                    onDueSubscriptionTap: _navigateToAddSubscriptionTransaction,
                    onDueSubscriptionDismiss: (sub) {
                      // Logic for logic dismissal if needed, or re-use removePending logic?
                      // Original used _showDismissDueSubscriptionDialog which just removed.
                      // But Subscriptions are localPrefs?
                      // Ah, _dueSubscriptions logic in original code:
                      // Not implemented. It just called _showDismissConfirmationDialog
                      // which only removed SMS from native side.
                      // It didn't remove subscription due alert from the list permanently?
                      // Actually, `_dueSubscriptions` is loaded from SharedPreferences.
                      // I should add removing from that list + save.
                      setState(() {
                        _dueSubscriptions.remove(sub);
                      });
                      _saveDueSubscriptions();
                    },
                    onIgnoreAll: _handleDismissAllPending,
                    onShowAllTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PendingSmsScreen(
                            transactions: _pendingSmsTransactions,
                            onAdd: (tx) async {
                              final result =
                                  await _navigateToTransactionFromData(tx);
                              if (result == true) {
                                _platform.invokeMethod(
                                  'removePendingSmsTransaction',
                                  {'id': tx['id']},
                                );
                                setState(() {
                                  _pendingSmsTransactions.removeWhere(
                                    (e) => e['id'] == tx['id'],
                                  );
                                });
                              }
                              return result == true;
                            },
                            onDismiss: (tx) {
                              _platform.invokeMethod(
                                'removePendingSmsTransaction',
                                {'id': tx['id']},
                              );
                              setState(() {
                                _pendingSmsTransactions.removeWhere(
                                  (e) => e['id'] == tx['id'],
                                );
                              });
                            },
                            onUndo: (tx) {
                              // Undo logic...
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 3. ANALYTICS POD
              if (transactionProvider.transactions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                    child: AnalyticsWidget(
                      selectedTimeframe: _selectedTimeframe,
                      onTimeframeChanged: (val) {
                        setState(() {
                          _selectedTimeframe = val;
                        });
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: HomeWidgetsSection(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 4. RECENT ACTIVITY
              SliverToBoxAdapter(
                child: RecentActivityWidget(
                  transactions: recentTransactions,
                  onTap: (tx) => _showTransactionDetails(context, tx),
                ),
              ),

              const SliverToBoxAdapter(child: FooterGraphic()),
            ],
          ),
          Positioned(
            bottom: 50, // Margin from the bottom
            left: 0,
            right: 0,
            child: Center(child: _buildGlassFab()),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFab() {
    return GlassRadialMenu(
      isFabExtended: _isFabExtended,
      onFabTap: _navigateToAddTransactionScreen,
      menuItems: [
        RadialMenuItem(
          icon: HugeIcons.strokeRoundedAddInvoice,
          label: 'TRANSACTION',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
          ),
        ),
        RadialMenuItem(
          icon: HugeIcons.strokeRoundedRotate02,
          label: 'RECURRING',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
          ),
        ),
        RadialMenuItem(
          icon: HugeIcons.strokeRoundedArrowReloadVertical,
          label: 'DEBT/LOAN',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDebtLoanScreen()),
          ),
        ),
        RadialMenuItem(
          icon: HugeIcons.strokeRoundedWalletAdd02,
          label: 'ACCOUNT',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
          ),
        ),
      ],
    );
  }

  // ... [Existing Helper Methods: permissions, launchData, sms, autoRecord]
  // I will just copy the existing handlers as they are robust.

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> _processLaunchData() async {
    try {
      final data = await _platform.invokeMethod('getLaunchData');
      if (data != null) {
        if (data is String) {
          final map = jsonDecode(data);
          if (map['type'] == 'sms_transaction') {
            _navigateToTransactionFromData(map);
          } else if (map['type'] == 'due_subscription') {
            _navigateToAddSubscriptionTransaction(map);
          }
        } else if (data['type'] == 'sms_transaction') {
          _navigateToTransactionFromData(data);
        } else if (data['type'] == 'due_subscription') {
          _navigateToAddSubscriptionTransaction(data);
        }
      }
    } catch (e) {
      debugPrint("Error processing launch data: $e");
    }
  }

  Future<void> _fetchPendingSmsTransactions() async {
    try {
      final String? jsonString = await _platform.invokeMethod(
        'getPendingSmsTransactions',
      );
      if (jsonString != null) {
        final List<dynamic> list = jsonDecode(jsonString);
        final List<Map<String, dynamic>> typedList = list
            .cast<Map<String, dynamic>>()
            .toList();

        // Deduplicate based on 'id'
        final uniqueList = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        for (var item in typedList) {
          final id = item['id']?.toString();
          if (id != null && !seenIds.contains(id)) {
            uniqueList.add(item);
            seenIds.add(id);
          } else if (id == null) {
            // Keep items without ID? Or risky?
            // Usually valid SMS items have IDs. Let's keep them but maybe they are duplicates?
            // Safest to keep for now, but prioritize ID check.
            uniqueList.add(item);
          }
        }

        uniqueList.sort((a, b) {
          final int tA = a['timestamp'] ?? 0;
          final int tB = b['timestamp'] ?? 0;
          return tB.compareTo(tA);
        });

        setState(() {
          _pendingSmsTransactions.clear();
          _pendingSmsTransactions.addAll(uniqueList);
        });
      }
    } catch (e) {
      debugPrint("Error fetching pending SMS transactions: $e");
    }
  }

  Future<void> _processAutoRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoRecord = prefs.getBool('auto_record_transactions') ?? false;

    if (!shouldAutoRecord) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    int retries = 0;
    while (authProvider.isAuthLoading && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    if (!mounted) return;

    if (!authProvider.isLoggedIn) {
      return;
    }

    if (_pendingSmsTransactions.isEmpty) return;

    _autoRecordTotal.value = _pendingSmsTransactions.length;
    _autoRecordProgress.value = 0;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<int>(
          valueListenable: _autoRecordProgress,
          builder: (context, progress, _) {
            final total = _autoRecordTotal.value;
            return Text(
              "Recording transactions... $progress / $total",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            );
          },
        ),
        duration: const Duration(days: 1),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);

    int savedCount = 0;

    final List<Map<String, dynamic>> pending = List.from(
      _pendingSmsTransactions,
    );

    for (final txData in pending) {
      try {
        final amount = (txData['amount'] as num).toDouble();
        final type = txData['type'] ?? 'expense';
        final bankName = txData['bankName'] as String?;
        final accountNumber = txData['accountNumber'] as String?;
        final payee = txData['payee'] as String?;

        DateTime date;
        if (txData['timestamp'] != null && txData['timestamp'] is int) {
          date = DateTime.fromMillisecondsSinceEpoch(txData['timestamp']);
        } else {
          date = DateTime.now();
        }

        String? accountId;
        if (bankName != null && accountNumber != null) {
          final account = await accountProvider.findOrCreateAccount(
            bankName: bankName,
            accountNumber: accountNumber,
          );
          accountId = account.id;
        } else if (type == 'expense' &&
            payee != null &&
            payee.toLowerCase().contains('upi')) {
          final primary = await accountProvider.getPrimaryAccount();
          accountId = primary?.id;
        } else {
          final primary = await accountProvider.getPrimaryAccount();
          accountId = primary?.id;
        }

        // Check for Auto-Add Tags
        final List<Tag> tags = metaProvider.getAutoAddTagsForDate(date);

        final newTx = TransactionModel(
          transactionId: const Uuid().v4(),
          type: type,
          amount: amount,
          timestamp: date,
          description: payee ?? (type == 'income' ? 'Received' : 'Spent'),
          paymentMethod: txData['paymentMethod'] ?? 'Unknown',
          category: txData['category'] ?? 'Others',
          currency: settingsProvider.currencyCode,
          accountId: accountId,
          tags: tags,
        );

        await txProvider.addTransaction(newTx);

        await _platform.invokeMethod('removePendingSmsTransaction', {
          'id': txData['id'],
        });

        savedCount++;
        _autoRecordProgress.value = savedCount;

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint("Error auto-saving transaction: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (savedCount > 0) {
      setState(() {
        _pendingSmsTransactions.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Auto-recorded $savedCount transactions",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllTransactionsScreen(),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDueSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('due_subscriptions');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        _dueSubscriptions.clear();
        _dueSubscriptions.addAll(
          jsonList.map((e) => DueSubscription.fromMap(e)).toList(),
        );
      });
    }
  }

  Future<void> _saveDueSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      _dueSubscriptions.map((e) => e.toMap()).toList(),
    );
    await prefs.setString('due_subscriptions', jsonString);
  }

  Future<void> _handleSms(MethodCall call) async {
    switch (call.method) {
      case 'newTransaction':
        final args = Map<String, dynamic>.from(call.arguments);
        final id = args['id']?.toString();
        setState(() {
          // Check for duplicates before inserting
          final exists = _pendingSmsTransactions.any(
            (tx) => tx['id']?.toString() == id,
          );
          if (!exists) {
            _pendingSmsTransactions.insert(0, args);
          }
        });
        break;
      case 'onSmsReceived':
        Map<String, dynamic> args;
        if (call.arguments is String) {
          args = Map<String, dynamic>.from(jsonDecode(call.arguments));
        } else {
          args = Map<String, dynamic>.from(call.arguments);
        }

        setState(() {
          final id = args['id'];
          final exists = _pendingSmsTransactions.any((tx) => tx['id'] == id);
          if (!exists) {
            _pendingSmsTransactions.insert(0, args);
          }
        });
        _navigateToTransactionFromData(args);
        break;
      case 'dueSubscription':
        final args = Map<String, dynamic>.from(call.arguments);
        final dueSub = DueSubscription.fromMap(args);
        setState(() {
          _dueSubscriptions.add(dueSub);
        });
        _saveDueSubscriptions();
        break;
      case 'newPendingSmsAvailable':
        await _fetchPendingSmsTransactions();
        await _processAutoRecord();
        break;
    }
  }

  Future<bool?> _navigateToTransactionFromData(dynamic args) async {
    if (args == null) return false;
    final map = Map<String, dynamic>.from(args);

    DateTime? initialDate;
    if (map['timestamp'] != null) {
      initialDate = DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      );
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTransactionScreen(
          initialMode: (map['type']?.toString().toLowerCase() == 'income')
              ? TransactionMode.income
              : TransactionMode.expense,
          initialAmount: map['amount']?.toString(),
          initialDate: initialDate,
          initialPayee: map['payee'] ?? map['merchant'],
          initialAccountNumber: map['accountNumber'] ?? map['account'],
          initialBankName: map['bankName'] ?? map['bank'],
          initialCategory: map['category'],
          initialPaymentMethod: map['paymentMethod'],
          smsTransactionId: map['id']?.toString(),
        ),
      ),
    );

    if (result == true) {
      await _fetchPendingSmsTransactions();
    }
    return result;
  }

  void _navigateToAddSubscriptionTransaction(dynamic args) {
    // If it's just a DueSubscription object (from tap) or map (from launch)
    DueSubscription? sub;
    if (args is DueSubscription) {
      sub = args;
    } else if (args != null) {
      sub = DueSubscription.fromMap(Map<String, dynamic>.from(args));
    }

    if (sub == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTransactionScreen(
          initialMode: TransactionMode.expense,
          initialAmount: sub!.averageAmount.toString(),
          initialPayee: sub.subscriptionName,
          initialCategory: sub.lastCategory,
          initialPaymentMethod: sub.lastPaymentMethod,
        ),
      ),
    );
  }

  void _navigateToAddTransactionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
    );
  }

  void _showTransactionDetails(BuildContext ctx, dynamic tx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailScreen(transaction: tx),
    );
  }
}

class BreathingLogo extends StatefulWidget {
  final double size;
  final Color color;
  final String assetPath;

  const BreathingLogo({
    super.key,
    this.size = 120.0, // Slightly larger for impact
    required this.color,
    required this.assetPath,
  });

  @override
  State<BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<BreathingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // Slower, deeper breath
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _fadeAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Breathing Glow/Shadow behind
            Transform.scale(
              scale: _scaleAnimation.value * 1.2,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(_fadeAnimation.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            // 2. The Actual SVG Logo
            Transform.scale(
              scale: _scaleAnimation.value,
              child: SvgPicture.asset(
                widget.assetPath,
                width: widget.size,
                height: widget.size,
                colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
              ),
            ),
          ],
        );
      },
    );
  }
}
