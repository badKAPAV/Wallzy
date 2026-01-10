import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui'; // For ImageFilter
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/common/widgets/messages_permission_banner.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/features/dashboard/models/radial_menu_item_model.dart';
import 'package:wallzy/features/dashboard/widgets/rotating_balance.dart';

import 'package:wallzy/features/dashboard/widgets/home_empty_state.dart';
import 'package:wallzy/features/subscription/models/due_subscription.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
import 'package:wallzy/features/transaction/screens/pending_sms_screen.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/grouped_transaction_list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';
import 'package:wallzy/features/people/screens/add_debt_loan_screen.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:uuid/uuid.dart'; // For generating IDs

// --- VISUALIZATION MODELS ---
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

enum Timeframe { weeks, months, years }

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
  Timeframe _selectedTimeframe = Timeframe.months;
  bool _isBalanceVisible = false;
  bool _minLoadingFinished = false; // NEW: Track min loading time

  // variables for dismissable sms transactions
  double _actionDeckOverscroll = 0.0;
  bool _isDismissTriggered = false;
  static const double _dismissThreshold = 90.0;

  // ...

  // CurrencySymbol userCurrency(BuildContext context) =>
  //    CurrencySymbol(symbol: '₹');

  Timer? _titleTimer;
  // String _headerTitle = ""; // Will be set in initState

  final List<String> _quotes = [
    "Keeping in check?",
    "Every penny counts!",
    "Save first, spend later",
    "Financial freedom is key",
    "Track to hack",
    "Mindful spending is best",
    "Master your money flow",
    "Checking your reports?",
  ];

  bool _isAutoRecording = true; // Start true to block UI until check is done
  final ValueNotifier<int> _autoRecordTotal = ValueNotifier(0);
  final ValueNotifier<int> _autoRecordProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    // Start min loading timer
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _minLoadingFinished = true;
        });
      }
    });

    _initConnectivityListener();

    // _startTitleTimer();
    _requestPermissions();
    _platform.setMethodCallHandler(_handleSms);
    WidgetsBinding.instance.addObserver(this);
    _processLaunchData();
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

    // Run Auto Record Logic
    // We do this concurrently but keep _isAutoRecording true until done
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
      // On resume, we can define if we want to blocking load or not.
      // Usually, background resume shouldn't block UI hard, but maybe show a snackbar.
      // For now, let's keep it non-blocking on resume unless user explicitely requested.
      // User said "during the initial loading", implying start up.
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
    // 1. Initial Check
    _checkInitialConnectivity();

    // 2. Listen to changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      final settingsProvider = context.read<SettingsProvider>();
      final isOffline = settingsProvider.isOffline;

      if (!hasConnection && !isOffline) {
        // CASE: Lost Connection -> Switch to Offline Mode IMMEDIATELY
        _switchToOfflineMode();
      } else if (hasConnection && isOffline) {
        // CASE: Regained Connection but App is in Offline Mode -> Show "Back Online" Snackbar
        _showBackOnlineSnackbar();
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    // On startup, we trust the system state directly without waiting for a transition
    if (!hasConnection) {
      _switchToOfflineMode(showSnackbar: true);
    } else {
      // Ensure we start online if connected
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
            await FirebaseFirestore.instance.enableNetwork(); // GO ONLINE
            if (mounted) {
              context.read<SettingsProvider>().setOfflineStatus(
                false,
              ); // REMOVE BADGE
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),
        duration: const Duration(
          days: 1,
        ), // Keep visible until interaction or state change
      ),
    );
  }

  // void _startTitleTimer() {
  //   _titleTimer?.cancel();
  //   // Start with a random quote
  //   setState(() {
  //     _headerTitle = _quotes[Random().nextInt(_quotes.length)];
  //   });

  //   _titleTimer = Timer(const Duration(seconds: 5), () {
  //     if (mounted) {
  //       setState(() {
  //         _headerTitle = "LEDGR";
  //       });
  //     }
  //   });
  // }

  Future<void> _handleDismissAllPending() async {
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
      // Clear Native Storage
      for (var tx in _pendingSmsTransactions) {
        if (tx['id'] != null) {
          _platform.invokeMethod('removePendingSmsTransaction', {
            'id': tx['id'],
          });
        }
      }

      // Animate out
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
    final user = authProvider.user;
    final transactionProvider = Provider.of<TransactionProvider>(context);

    // Show loading if provider is loading OR min time hasn't passed OR auto-recording is in progress
    // AND wait for settings to load
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isLoading =
        transactionProvider.isLoading ||
        !_minLoadingFinished ||
        _isAutoRecording ||
        !settingsProvider.isSettingsLoaded;

    // Define recentTransactions here so it is available in scope
    final recentTransactions = transactionProvider.transactions
        .take(8)
        .toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1000),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: isLoading
          ? Scaffold(
              key: const ValueKey('loading_screen'),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 340),
                    SpinKitCubeGrid(
                      color: Theme.of(context).colorScheme.primary,
                      size: 80.0,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isAutoRecording)
                            ValueListenableBuilder<int>(
                              valueListenable: _autoRecordTotal,
                              builder: (context, total, _) {
                                if (total <= 0) {
                                  return Text(
                                    _quotes[Random().nextInt(_quotes.length)],
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 22,
                                        ),
                                  ).animate().fadeIn(duration: 800.ms);
                                }
                                return ValueListenableBuilder<int>(
                                  valueListenable: _autoRecordProgress,
                                  builder: (context, progress, _) {
                                    final percentage = total > 0
                                        ? progress / total
                                        : 0.0;
                                    return Column(
                                      children: [
                                        Text(
                                          "Recorded $progress out of $total transactions",
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                        ).animate().fadeIn(duration: 400.ms),
                                        const SizedBox(height: 16),
                                        LinearProgressIndicator(
                                          value: percentage,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "${(percentage * 100).toInt()}%",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            )
                          else
                            Text(
                              _quotes[Random().nextInt(_quotes.length)],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 22,
                                  ),
                            ).animate().fadeIn(duration: 800.ms),
                        ],
                      ),
                    ),
                    const SizedBox(height: 260),
                    Text(
                      'ledgr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'momo',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Scaffold(
              key: const ValueKey('main_dashboard'),
              drawer: _isProcessingSms ? null : const AppDrawer(),
              body: Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. HERO HEADER (Replaces AppBar + Balance Card)
                      _buildImmersiveHeader(user),

                      // 2. ACTION DECK (Replaces Action Center TabView)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: MessagesPermissionBanner(
                            // debugForceShow: true        //! TURN ON FOR DEBUG
                          ),
                        ),
                      ),

                      if (_pendingSmsTransactions.isNotEmpty ||
                          _dueSubscriptions.isNotEmpty)
                        SliverToBoxAdapter(child: _buildActionDeck()),

                      // 3. ANALYTICS POD (Replaces Summary Card)
                      if (transactionProvider.transactions.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              16.0,
                              16.0,
                              0,
                            ),
                            child: _buildAnalyticsPod(transactionProvider),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 4. TRANSACTION FEED
                      if (transactionProvider.transactions.isNotEmpty)
                        _buildTransactionHeader(),

                      if (recentTransactions.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: HomeEmptyState(),
                        )
                      else
                        GroupedTransactionList(
                          transactions: recentTransactions,
                          onTap: (tx) => _showTransactionDetails(context, tx),
                          useSliver: true,
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ],
              ),
              floatingActionButton: _buildGlassFab(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
            ),
    );
  }

  // --- 1. HERO HEADER ---
  Widget _buildImmersiveHeader(user) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final totalCash = accountProvider.getTotalAvailableCash(
      txProvider.transactions,
    );
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 260,
      collapsedHeight: 60, // Slightly taller for better touch targets
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Moves the glow here so it's not covered by the appbar tint
            Positioned(
              top: -170,
              right: -180,
              left: -180,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: SvgPicture.asset(
                  'assets/vectors/home_gradient_vector.svg',
                  width: 300,
                  height: 300,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            // The actual content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Spacer for Expanded state
                    Text(
                      "Total Balance",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.5, end: 0),

                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () {
                        HapticFeedback.vibrate();
                        setState(() => _isBalanceVisible = !_isBalanceVisible);
                      },
                      // Replaced AnimatedCrossFade with the new RollingBalance widget
                      child: accountProvider.isLoading
                          ? Shimmer.fromColors(
                              baseColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              highlightColor: theme.colorScheme.surface,
                              child: Container(
                                width: 200,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : RollingBalance(
                              isVisible: _isBalanceVisible,
                              symbol: settingsProvider.currencySymbol,
                              amount: totalCash,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                // IMPORTANT: Explicit height helps the math for the scrolling offset
                                height: 1.1,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Mini quick stats
                    Row(
                      children: [
                        _HeaderChip(
                          icon: Icons.trending_up,
                          label: "Income",
                          value: _getTrendData(
                            txProvider,
                            _selectedTimeframe,
                            'income',
                          ),
                          color: Colors.greenAccent.shade700,
                        ),
                        const SizedBox(width: 12),
                        _HeaderChip(
                          icon: Icons.trending_down,
                          label: "Spend",
                          value: _getTrendData(
                            txProvider,
                            _selectedTimeframe,
                            'expense',
                          ),
                          color: Colors.orangeAccent.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          // Custom Drawer Trigger - Removed as per request
          // IconButton(
          //   onPressed: () => Scaffold.of(context).openDrawer(),
          //   icon: const Icon(Icons.menu),
          // ),
          // Expanded(
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     child: AnimatedSwitcher(
          //       duration: 600.ms,
          //       transitionBuilder: (child, animation) {
          //         return FadeTransition(
          //           opacity: animation,
          //           child: SlideTransition(
          //             position: Tween<Offset>(
          //               begin: const Offset(0, 0.2),
          //               end: Offset.zero,
          //             ).animate(animation),
          //             child: child,
          //           ),
          //         );
          //       },
          //       child: Text(
          //         _headerTitle,
          //         key: ValueKey(_headerTitle),
          //         style: theme.textTheme.titleMedium?.copyWith(
          //           fontWeight: FontWeight.w600,
          //           fontSize: 15,
          //           color: theme.colorScheme.onSurface,
          //         ),
          //         textAlign: TextAlign.center,
          //         maxLines: 1,
          //         overflow: TextOverflow.ellipsis,
          //       ),
          //     ),
          //   ),
          // ),
          Expanded(
            child: Text(
              'ledgr',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Contextual Actions
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchTransactionsScreen(),
                  ),
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  strokeWidth: 2,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      titleSpacing: 20,
    );
  }

  // --- 2. ACTION DECK (Horizontal Scroll) ---
  // --- 2. ACTION DECK (Horizontal Scroll with Pull-to-Dismiss) ---
  Widget _buildActionDeck() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    final highValueTransactions = _pendingSmsTransactions
        .where((tx) {
          final amount = (tx['amount'] as num).toDouble();
          return amount >= 100;
        })
        .take(10)
        .toList();

    final totalPendingAmount = _pendingSmsTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + (tx['amount'] as num).toDouble(),
    );

    final theme = Theme.of(context);
    final isTriggered = _actionDeckOverscroll.abs() > _dismissThreshold;

    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // 1. BACKGROUND INDICATOR
          Positioned(
            left: 20,
            child: Opacity(
              opacity: (_actionDeckOverscroll.abs() / _dismissThreshold).clamp(
                0.0,
                1.0,
              ),
              child:
                  Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: isTriggered
                              ? theme.colorScheme.error
                              : theme.colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: isTriggered
                              ? theme.colorScheme.onError
                              : theme.colorScheme.onSurfaceVariant,
                          size: isTriggered ? 28 : 24,
                        ),
                      )
                      .animate(target: isTriggered ? 1 : 0)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.2, 1.2),
                        duration: 200.ms,
                        curve: Curves.easeOutBack,
                      ),
            ),
          ),

          // 2. SCROLLABLE LIST WITH POINTER LISTENER
          Listener(
            // TRIGGER DIALOG INSTANTLY ON FINGER LIFT
            onPointerUp: (_) {
              if (isTriggered) {
                _handleDismissAllPending();
                // Reset trigger to prevent double haptics during bounce back
                _isDismissTriggered = false;
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  // Track left overscroll (pixels < 0)
                  if (notification.metrics.pixels < 0) {
                    final overscroll = notification.metrics.pixels;
                    // Only update UI if values changed significantly to save rebuilds
                    if ((_actionDeckOverscroll - overscroll).abs() > 1) {
                      setState(() => _actionDeckOverscroll = overscroll);
                    }

                    // Haptic Logic
                    if (overscroll.abs() > _dismissThreshold &&
                        !_isDismissTriggered) {
                      HapticFeedback.mediumImpact();
                      _isDismissTriggered = true;
                    } else if (overscroll.abs() < _dismissThreshold &&
                        _isDismissTriggered) {
                      _isDismissTriggered = false;
                    }
                  } else {
                    // Reset if we are not overscrolling anymore
                    if (_actionDeckOverscroll != 0) {
                      setState(() => _actionDeckOverscroll = 0.0);
                    }
                  }
                }
                return false;
              },
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  ...highValueTransactions.map(
                    (tx) => _ActionCard(
                      currencySymbol: currencySymbol,
                      title: "New Transaction",
                      subtitle: "Detected via SMS",
                      amount: (tx['amount'] as num).toDouble(),
                      icon: Icons.sms_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () async {
                        final result = await _navigateToTransactionFromData(tx);
                        if (result == true) {
                          setState(() {
                            _pendingSmsTransactions.removeWhere(
                              (e) => e['id'] == tx['id'],
                            );
                          });
                        }
                      },
                      onDismiss: () => _showDismissConfirmationDialog(tx),
                    ),
                  ),
                  ..._dueSubscriptions.map(
                    (sub) => _ActionCard(
                      currencySymbol: currencySymbol,
                      title: sub.subscriptionName,
                      subtitle: "Subscription Due",
                      amount: sub.averageAmount,
                      icon: Icons.autorenew_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      onTap: () => _navigateToAddSubscriptionTransaction(sub),
                      onDismiss: () => _showDismissDueSubscriptionDialog(sub),
                    ),
                  ),
                  if (_pendingSmsTransactions.isNotEmpty)
                    _ActionCard(
                      currencySymbol: currencySymbol,
                      title: "Show All",
                      subtitle: "${_pendingSmsTransactions.length} pending",
                      amount: totalPendingAmount,
                      icon: Icons.task_alt,
                      color: Colors.indigoAccent,
                      isSummary: true,
                      onTap: () {
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
                      onDismiss: () async => false, // Handled by pull
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. ANALYTICS POD ---
  Widget _buildAnalyticsPod(TransactionProvider txProvider) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    final theme = Theme.of(context);
    final summaries = _getChartSummaries(txProvider, _selectedTimeframe);

    // Calc logic for display
    final range = _getFilterRangeForTimeframe(_selectedTimeframe);
    final income = txProvider.getTotal(
      start: range.start,
      end: range.end,
      type: 'income',
    );
    final expense = txProvider.getTotal(
      start: range.start,
      end: range.end,
      type: 'expense',
    );

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTransactionsScreen(),
                    ),
                  );
                },
                child: Row(
                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                      ), //*  ===== NEW =====
                      child: Text(
                        "Cash Flow",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                          fontFamily: 'momo',
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 6,
                        left: 10,
                      ), //*  ===== NEW =====
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCoins01,
                        color: theme.colorScheme.primary,
                        size: 22,
                        strokeWidth: 2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 2,
                      ), //*  ===== NEW =====
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedFastWind,
                        color: theme.colorScheme.primary.withAlpha(150),
                        size: 18,
                        strokeWidth: 1,
                      ),
                    ),
                    // _TimeframePill(
                    //   selected: _selectedTimeframe,
                    //   onChanged: (val) => setState(() => _selectedTimeframe = val),
                    // ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Clean Stats Row
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTransactionsScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      currencySymbol: currencySymbol,
                      label: "In",
                      amount: income,
                      color: theme.extension<AppColors>()!.income,
                    ),
                    Container(width: 1, height: 30, color: theme.dividerColor),
                    _StatColumn(
                      currencySymbol: currencySymbol,
                      label: "Out",
                      amount: expense,
                      color: theme.extension<AppColors>()!.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // The Funky Chart
              SizedBox(
                height: 120,
                child: _BiDirectionalBarChart(summaries: summaries),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _TimeframePill(
              selected: _selectedTimeframe,
              onChanged: (val) => setState(() => _selectedTimeframe = val),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. TRANSACTION HEADER ---
  Widget _buildTransactionHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Activity",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllTransactionsScreen(),
                ),
              ),
              child: const Text("View All"),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. GLASS FAB ---
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

  // --- 6. HELPERS ---

  String _getTrendData(
    TransactionProvider provider,
    Timeframe timeframe,
    String type,
  ) {
    double current = 0;
    double previous = 0;
    final now = DateTime.now();

    if (timeframe == Timeframe.weeks) {
      if (type == 'income') {
        current = provider.thisWeekIncome;
        previous = provider.lastWeekIncome;
      } else {
        current = provider.thisWeekExpense;
        previous = provider.lastWeekExpense;
      }
    } else if (timeframe == Timeframe.months) {
      if (type == 'income') {
        current = provider.thisMonthIncome;
        previous = provider.lastMonthIncome;
      } else {
        current = provider.thisMonthExpense;
        previous = provider.lastMonthExpense;
      }
    } else if (timeframe == Timeframe.years) {
      // Custom Year Logic (Jan 1 to Now vs Last Year Jan 1 to Dec 31)
      final startOfYear = DateTime(now.year, 1, 1);
      final nextYear = DateTime(now.year + 1, 1, 1);
      final startOfLastYear = DateTime(now.year - 1, 1, 1);
      final endOfLastYear = DateTime(now.year, 1, 1); // Exclusive

      current = provider.getTotal(
        start: startOfYear,
        end: nextYear,
        type: type,
      );
      previous = provider.getTotal(
        start: startOfLastYear,
        end: endOfLastYear,
        type: type,
      );
    }

    if (previous == 0) {
      if (current == 0) return "0%";
      return "+100%"; // Infinite growth from 0
    }

    final percent = ((current - previous) / previous) * 100;
    final sign = percent >= 0 ? "+" : "";
    return "$sign${percent.toStringAsFixed(0)}%";
  }

  DateTimeRange _getFilterRangeForTimeframe(Timeframe timeframe) {
    final now = DateTime.now();
    switch (timeframe) {
      case Timeframe.weeks:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: now.add(const Duration(days: 1)),
        );
      case Timeframe.months:
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        return BudgetCycleHelper.getCycleRange(
          targetMonth: now.month,
          targetYear: now.year,
          mode: settings.budgetCycleMode,
          startDay: settings.budgetCycleStartDay,
        );
      case Timeframe.years:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now.add(const Duration(days: 1)),
        );
    }
  }

  List<_PeriodSummary> _getChartSummaries(
    TransactionProvider txProvider,
    Timeframe timeframe,
  ) {
    final now = DateTime.now();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    List<_PeriodSummary> summaries = [];
    // Just showing last 5 bars for cleaner UI in the redesign
    for (int i = 4; i >= 0; i--) {
      DateTimeRange range;
      String label;
      switch (timeframe) {
        case Timeframe.weeks:
          final startDay = now.subtract(
            Duration(days: now.weekday - 1 + (i * 7)),
          );
          range = DateTimeRange(
            start: startDay,
            end: startDay.add(const Duration(days: 7)),
          );
          label = DateFormat('d MMM').format(startDay);
          break;
        case Timeframe.months:
          // Calculate target month/year for (now - i months)
          var targetMonth = now.month - i;
          var targetYear = now.year;
          while (targetMonth <= 0) {
            targetMonth += 12;
            targetYear--;
          }

          range = BudgetCycleHelper.getCycleRange(
            targetMonth: targetMonth,
            targetYear: targetYear,
            mode: settings.budgetCycleMode,
            startDay: settings.budgetCycleStartDay,
          );

          final midPoint = range.start.add(const Duration(days: 15));
          label = DateFormat('MMM').format(midPoint);
          break;
        case Timeframe.years:
          final year = DateTime(now.year - i, 1, 1);
          range = DateTimeRange(
            start: year,
            end: DateTime(year.year + 1, 1, 1),
          );
          label = DateFormat('yyyy').format(year);
          break;
      }
      final income = txProvider.getTotal(
        start: range.start,
        end: range.end,
        type: 'income',
      );
      final expense = txProvider.getTotal(
        start: range.start,
        end: range.end,
        type: 'expense',
      );
      summaries.add(
        _PeriodSummary(label: label, income: income, expense: expense),
      );
    }
    return summaries;
  }

  // --- RESTORED OFFLINE LOGIC ---

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> _processLaunchData() async {
    try {
      final data = await _platform.invokeMethod('getLaunchData');
      debugPrint("Flutter _processLaunchData: Received: $data");
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
      debugPrint("Flutter _fetchPendingSmsTransactions: Received: $jsonString");
      if (jsonString != null) {
        final List<dynamic> list = jsonDecode(jsonString);
        setState(() {
          _pendingSmsTransactions.clear();
          _pendingSmsTransactions.addAll(list.cast<Map<String, dynamic>>());
        });
      }
    } catch (e) {
      debugPrint("Error fetching pending SMS transactions: $e");
    }
  }

  Future<void> _processAutoRecord() async {
    // FIX: Directly check SharedPreferences to avoid race condition with Provider initialization
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoRecord = prefs.getBool('auto_record_transactions') ?? false;

    if (!shouldAutoRecord) return;

    // FIX: Wait for auth to be determined
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

    if (!mounted) return; // FIX: Check mounted after async wait

    if (!authProvider.isLoggedIn) {
      debugPrint("Auto-record aborted: User not logged in after waiting.");
      return;
    }

    if (_pendingSmsTransactions.isEmpty) return;

    // Setup Progress
    _autoRecordTotal.value = _pendingSmsTransactions.length;
    _autoRecordProgress.value = 0;

    // Show persistent progress snackbar
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
        duration: const Duration(days: 1), // Persistent until dismissed
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Providers must be accessed only if mounted, but we checked above.
    // However, it's safer to grab them now.
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );

    int savedCount = 0;

    // Iterate through a copy to avoid modification errors
    final List<Map<String, dynamic>> pending = List.from(
      _pendingSmsTransactions,
    );

    for (final txData in pending) {
      try {
        // ... (existing helper logic)
        // 1. Extract Data
        final amount = (txData['amount'] as num).toDouble();
        final type = txData['type'] ?? 'expense';
        final bankName = txData['bankName'] as String?;
        final accountNumber = txData['accountNumber'] as String?;
        final payee = txData['payee'] as String?;
        // final notificationId = txData['notificationId']; // Unused

        // Date parsing: Critical req.
        DateTime date;
        if (txData['timestamp'] != null && txData['timestamp'] is int) {
          date = DateTime.fromMillisecondsSinceEpoch(txData['timestamp']);
        } else {
          date = DateTime.now(); // Fallback
        }

        // 2. Resolve Account
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

        // 3. Create Model
        final newTx = TransactionModel(
          transactionId: const Uuid().v4(),
          type: type,
          amount: amount,
          timestamp: date, // Use the Recorded Date!
          description: payee ?? (type == 'income' ? 'Received' : 'Spent'),
          paymentMethod: txData['paymentMethod'] ?? 'Unknown',
          category:
              txData['category'] ??
              'Others', // Sme Receiver logic might need enhancement for defaulting
          currency: settingsProvider.currencyCode,
          accountId: accountId,
        );

        // 4. Save
        await txProvider.addTransaction(newTx);

        // 5. Cleanup Native
        await _platform.invokeMethod('removePendingSmsTransaction', {
          'id': txData['id'],
        });

        savedCount++;
        _autoRecordProgress.value = savedCount;

        // Small delay to make the progress bar visible/smooth
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint("Error auto-saving transaction: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide progress

    if (savedCount > 0) {
      setState(() {
        // Clear local list as we processed them
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
    debugPrint("Flutter _handleSms: Received method ${call.method}");
    debugPrint("Flutter _handleSms: Arguments: ${call.arguments}");

    switch (call.method) {
      case 'newTransaction':
        final args = Map<String, dynamic>.from(call.arguments);
        setState(() {
          _pendingSmsTransactions.insert(0, args);
        });
        break;
      case 'onSmsReceived':
        Map<String, dynamic> args;
        if (call.arguments is String) {
          args = Map<String, dynamic>.from(jsonDecode(call.arguments));
        } else {
          args = Map<String, dynamic>.from(call.arguments);
        }

        // We also want to add it to the pending list so it's there if they go back
        setState(() {
          // Avoid duplicates based on ID
          final id = args['id'];
          final exists = _pendingSmsTransactions.any((tx) => tx['id'] == id);
          if (!exists) {
            _pendingSmsTransactions.insert(0, args);
          }
        });
        // Navigate
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
        debugPrint(
          "Flutter _handleSms: Refreshing pending SMS transactions...",
        );
        await _fetchPendingSmsTransactions();
        // Also trigger auto-record if enabled
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

    // Fix Mapping: Native sends 'payee', 'bankName', 'accountNumber'
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTransactionScreen(
          initialMode: (map['type']?.toString().toLowerCase() == 'income')
              ? TransactionMode.income
              : TransactionMode.expense,
          initialAmount: map['amount']?.toString(),
          initialDate: initialDate,
          initialPayee:
              map['payee'] ?? map['merchant'], // Fix: Check 'payee' first
          initialAccountNumber:
              map['accountNumber'] ??
              map['account'], // Fix: Check 'accountNumber' first
          initialBankName:
              map['bankName'] ?? map['bank'], // Fix: Check 'bankName' first
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
    if (args == null) return;
    final sub = DueSubscription.fromMap(Map<String, dynamic>.from(args));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTransactionScreen(
          initialMode: TransactionMode.expense,
          initialAmount: sub.averageAmount.toString(),
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

  Future<bool> _showDismissConfirmationDialog(dynamic item) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Dismiss?"),
              content: const Text(
                "Are you sure you want to dismiss this suggestion?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    // Remove from native side if it's an SMS
                    if (item is Map && item['id'] != null) {
                      _platform.invokeMethod('removePendingSmsTransaction', {
                        'id': item['id'],
                      });
                      setState(() {
                        _pendingSmsTransactions.removeWhere(
                          (element) => element['id'] == item['id'],
                        );
                      });
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text("Dismiss"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> _showDismissDueSubscriptionDialog(dynamic item) async {
    return await _showDismissConfirmationDialog(item);
  }
}

// --- MICRO WIDGETS (THE FUNKY PARTS) ---

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String currencySymbol;
  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Future<bool> Function() onDismiss;
  final bool isSummary;

  const _ActionCard({
    required this.currencySymbol,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onDismiss,
    this.isSummary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSummary) {
      return Container(
        width: 140, // Slightly smaller than regular cards
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
        child: Material(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(160),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Show All",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currencySymbol ${amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withAlpha(204),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer.withAlpha(153),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dismissible(
      key: ValueKey(title + subtitle + amount.toString()),
      direction: DismissDirection.up,
      confirmDismiss: (_) => onDismiss(),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(58),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Suggestion",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$currencySymbol $amount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 18, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String currencySymbol;
  final String label;
  final double amount;
  final Color color;

  const _StatColumn({
    required this.currencySymbol,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          NumberFormat.compactCurrency(symbol: currencySymbol).format(amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BiDirectionalBarChart extends StatelessWidget {
  final List<_PeriodSummary> summaries;
  const _BiDirectionalBarChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Calculate global max for symmetry
    double maxY = 0;
    for (var s in summaries) {
      maxY = max(maxY, s.income);
      maxY = max(maxY, s.expense);
    }
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: -maxY, // Allow negative values for expense
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= summaries.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    summaries[index].label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: summaries.asMap().entries.map((e) {
          final index = e.key;
          final data = e.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              // Income Rod (Positive)
              BarChartRodData(
                toY: data.income,
                color: appColors.income,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.transparent,
                ),
              ),
              // Expense Rod (Negative visual hack: We normally use Stacks, but here we can just plot negative if FLChart supported it natively easily,
              // but standard BarChart expects positive base.
              // A trick: Use separate rods or a Stacked chart. For simplicity here:
              // We will just show them side by side or Stacked.
              // Let's go Side-by-Side but styled to look like they diverge from center)
              BarChartRodData(
                toY: -data.expense, // This might clip if min Y isn't set.
                // Let's actually do standard side-by-side for safety in this specific chart widget version
                // Or: To make it "Funky", let's use the standard side-by-side but with rounded styling.
                color: appColors.expense,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TimeframePill extends StatefulWidget {
  final Timeframe selected;
  final Function(Timeframe) onChanged;

  const _TimeframePill({required this.selected, required this.onChanged});

  @override
  State<_TimeframePill> createState() => _TimeframePillState();
}

class _TimeframePillState extends State<_TimeframePill> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedText =
        widget.selected.name[0].toUpperCase() +
        widget.selected.name.substring(1);

    // Determines the background styling based on state
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      boxShadow: [
        // Always show a small shadow since it's "floating" in a stack
        BoxShadow(
          color: Colors.black.withOpacity(_isExpanded ? 0.1 : 0.05),
          blurRadius: _isExpanded ? 12 : 4,
          offset: Offset(0, _isExpanded ? 6 : 2),
        ),
      ],
    );

    return TapRegion(
      onTapOutside: (event) {
        if (_isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isExpanded = !_isExpanded);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // No fixed width/height -> Wraps content
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            alignment: Alignment.topRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // State 1: Collapsed
                if (!_isExpanded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      // Flexible ensures it resizes to content text length
                      Text(
                        selectedText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),

                // State 2: Expanded List
                if (_isExpanded)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: Timeframe.values.map((tf) {
                      final isSelected = widget.selected == tf;
                      final text =
                          tf.name[0].toUpperCase() + tf.name.substring(1);

                      return GestureDetector(
                        onTap: () {
                          widget.onChanged(tf);
                          HapticFeedback.lightImpact();
                          setState(() => _isExpanded = false);
                        },
                        child: Container(
                          // Hit test area padding
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          color: Colors.transparent,
                          child: Text(
                            text,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _FunkyTransactionTile deprecated and removed. Using TransactionListItem via GroupedTransactionList.

// Keep the _EmptyState and other minor widgets from original file...

class CurrencySymbol {
  final String symbol;
  const CurrencySymbol({required this.symbol});
}

class GlassRadialMenu extends StatefulWidget {
  final List<RadialMenuItem> menuItems;
  final VoidCallback onFabTap;
  final bool isFabExtended;

  const GlassRadialMenu({
    super.key,
    required this.menuItems,
    required this.onFabTap,
    required this.isFabExtended,
  });

  @override
  State<GlassRadialMenu> createState() => _GlassRadialMenuState();
}

class _GlassRadialMenuState extends State<GlassRadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Rotation Logic
  double _currentRotation = 0.0;
  double _baseRotation = -math.pi / 2; // Start at -90 degrees (Straight up)

  bool get _isOpen => _overlayEntry != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
      HapticFeedback.mediumImpact();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    // Reset rotation when opening
    setState(() => _currentRotation = 0.0);
  }

  void _closeMenu() async {
    if (!_isOpen) return;
    await _controller.reverse();
    _removeOverlay();
    setState(() {}); // Rebuild to show the original FAB text if needed
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // --- The Overlay Logic ---
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 1. Blur & Dark Scrim (Excludes FAB visually by sitting under it in Stack)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                // Drag Logic for "Dial" feel
                onPanUpdate: (details) {
                  // Sensitivity factor
                  double delta = details.delta.dx * 0.01;
                  setState(() {
                    _currentRotation += delta;
                    // Clamp rotation to prevent full 360 spinning (keep it tight)
                    // Allow +/- 30 degrees (approx 0.5 radians) wiggle room
                    _currentRotation = _currentRotation.clamp(-0.5, 0.5);
                  });
                  _overlayEntry?.markNeedsBuild();
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    return BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 5 * value,
                        sigmaY: 5 * value,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(0.4 * value),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. The Radial Menu Items
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(-150, -152),
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final radius = 110.0 * _expandAnimation.value;

                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < widget.menuItems.length; i++)
                            _buildRadialItem(
                              index: i,
                              total: widget.menuItems.length,
                              radius: radius,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. The "Anchor" FAB
            // We render a copy of the FAB here so it sits ON TOP of the dark overlay
            // This creates the "Exclude" effect.
            Positioned(
              width: 60, // Force collapsed width
              height: 56,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset.zero,
                child: Material(
                  color: Colors.transparent,
                  child: _buildFabContent(isOverlay: true),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRadialItem({
    required int index,
    required int total,
    required double radius,
  }) {
    // Arc Logic: Distribute items over 180 degrees (Pi) centered at top
    // Start angle: -180 (Left) to 0 (Right). -90 is top.

    // Calculate total spread. If few items, keep them closer.
    final double spread = total > 1 ? math.pi * 0.8 : 0;
    final double startAngle = _baseRotation - (spread / 2);

    // Calculate angle for this specific item
    final double step = total > 1 ? spread / (total - 1) : 0;
    final double itemBaseAngle = startAngle + (step * index);

    // Add the user's drag rotation
    final double finalAngle = itemBaseAngle + _currentRotation;

    final double x = radius * math.cos(finalAngle);
    final double y = radius * math.sin(finalAngle);

    // Staggered Entrance Animation
    final double intervalStart = 0.0 + (index / total) * 0.5;
    final double intervalEnd = 0.5 + (index / total) * 0.5;

    final Animation<double> itemScale = CurvedAnimation(
      parent: _controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutBack),
    );

    return Transform.translate(
      offset: Offset(x, y),
      child: ScaleTransition(
        scale: itemScale,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            _closeMenu();
            widget.menuItems[index].onTap();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Glass Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: HugeIcon(
                    icon: widget.menuItems[index].icon,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                    size: 12,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Label with Shadow for readability on dark overlay
              Material(
                color: Colors.transparent,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.menuItems[index].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(204),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reuse the FAB design for both the main widget and the overlay copy
  Widget _buildFabContent({bool isOverlay = false}) {
    // If we are in the Overlay, force collapse.
    // If in main tree, respect isFabExtended UNLESS menu is open (then collapse)
    final bool effectiveExtended = isOverlay
        ? false
        : (widget.isFabExtended && !_isOpen);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: effectiveExtended ? 130 : 60,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            // If overlay is active, the shadow is handled by the overlay stack z-index mostly,
            // but we keep it for consistency.
            color: Theme.of(context).colorScheme.shadow.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // If in overlay, tap closes. If in main, tap opens normal action or Long press opens menu
          onTap: isOverlay ? _closeMenu : widget.onFabTap,
          onLongPress: isOverlay ? null : _toggleMenu,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _rotateAnimation,
                  child: Icon(
                    Icons.add_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                if (effectiveExtended) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Create",
                      style: TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      // When menu is open, we can either hide this FAB or leave it.
      // Leaving it prevents layout jumps. The Overlay FAB covers it perfectly.
      child: _buildFabContent(isOverlay: false),
    );
  }
}
