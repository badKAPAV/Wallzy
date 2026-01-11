import 'dart:async';
import 'dart:math'; // For randomizing animations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/core/themes/theme_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/common/widgets/messages_permission_banner.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/screens/currency_selection_screen.dart';
import 'package:wallzy/features/settings/widgets/theme_selector_widgets.dart';

String _getDaySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen>
    with WidgetsBindingObserver {
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  void _showDialog() {
    ModernAlertDialog.show(
      context,
      title: "Logout",
      description: "Are you sure you want to logout?",
      icon: HugeIcons.strokeRoundedLogoutSquare01,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: const Text(
            "Cancel",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
          child: const Text(
            "Confirm",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            authProvider.signOut();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Future<void> _checkPermission() async {
    final status = await MessagesPermissionBanner.checkPermission();
    if (mounted) {
      setState(() {
        _hasPermission = status;
      });
    }
  }

  Widget betaTag(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        "BETA",
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: false),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          const MessagesPermissionBanner(),

          _SectionHeader(title: "Display"),
          const SizedBox(height: 8),
          ThemeSelector(
            currentMode: themeProvider.themeMode,
            onThemeChanged: (mode) => themeProvider.setThemeMode(mode),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: "General"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return ListTile(
                    leading: Icon(
                      Icons.currency_exchange_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text(
                      "Currency",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "${settings.currencyCode} (${settings.currencySymbol})",
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CurrencySelectionScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: "Budget Cycle"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          "Cycle Mode",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: DropdownButton<BudgetCycleMode>(
                          value: settings.budgetCycleMode,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          borderRadius: BorderRadius.circular(16),
                          items: const [
                            DropdownMenuItem(
                              value: BudgetCycleMode.defaultMonth,
                              child: Text(
                                "Normal (1st - End)",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            DropdownMenuItem(
                              value: BudgetCycleMode.customDate,
                              child: Text(
                                "Custom Date",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            DropdownMenuItem(
                              value: BudgetCycleMode.lastDay,
                              child: Text(
                                "Last Day of month",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                          onChanged: (mode) {
                            if (mode != null) settings.setBudgetCycleMode(mode);
                          },
                        ),
                      ),
                      if (settings.budgetCycleMode ==
                          BudgetCycleMode.customDate) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        ListTile(
                          title: Text(
                            "Start Day",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            "Cycle starts on this day of the previous month.",
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          trailing: DropdownButton<int>(
                            value: settings.budgetCycleStartDay,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            borderRadius: BorderRadius.circular(16),
                            menuMaxHeight: 300,
                            items: List.generate(28, (index) {
                              final day = index + 1;
                              return DropdownMenuItem(
                                value: day,
                                child: Text(
                                  "$day${_getDaySuffix(day)}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }),
                            onChanged: (day) {
                              if (day != null) {
                                settings.setBudgetCycleStartDay(day);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: "Automation"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return Column(
                    children: [
                      SwitchListTile.adaptive(
                        value:
                            _hasPermission && settings.autoRecordTransactions,
                        onChanged: _hasPermission
                            ? (val) => settings.setAutoRecordTransactions(val)
                            : null,
                        title: Row(
                          children: [
                            Text(
                              "Enable AutoSave",
                              style: TextStyle(
                                color: _hasPermission
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedAiMagic,
                              color: _hasPermission
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                              strokeWidth: 2,
                              size: 14,
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Transactions get saved automatically",
                              style: TextStyle(
                                color: _hasPermission
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            betaTag(theme),
                          ],
                        ),
                        secondary: Icon(
                          Icons.bolt_rounded,
                          color: _hasPermission
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                        activeThumbColor: theme.colorScheme.primary,
                        activeTrackColor: theme.colorScheme.primaryContainer,
                        inactiveThumbColor: theme.colorScheme.outline,
                        inactiveTrackColor:
                            theme.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      if (!_hasPermission) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: theme.colorScheme.outlineVariant.withAlpha(
                            128,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: screenWidth * 0.4,
                                child: Text(
                                  "Notification access is required for this feature.",
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              MessagesPermissionBanner(isSmall: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- NEW: Privacy & Trust Section ---
          _SectionHeader(title: "Privacy & Trust"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.pinkAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  "ledgr Trust Circle",
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                subtitle: Text(
                  "Why we need permissions & data safety",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => _showTrustCircleDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: "Account"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
                title: Text(
                  "Logout",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
                onTap: () {
                  _showDialog();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showTrustCircleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(
            Icons.favorite_rounded,
            color: Colors.pinkAccent,
            size: 40,
          ),
          title: const Text(
            "Privacy n' Vibes",
            style: TextStyle(fontFamily: 'momo', fontWeight: FontWeight.w600),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "We keep it simple: Your money, your data, your device.",
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                "Ledgr processes SMS notifications locally to automate your tracking.\nWe don't upload your personal data, we don't sell it, and we definitely don't judge your spending habits.",
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                "We just want to help you understand where your money goes at the end of the month.",
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerEmoteBurst(context, "🔥");
              },
              child: const Text("Skeptical but okay 😏"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerEmoteBurst(context, "💖");
              },
              child: const Text("Fair Deal 🤝🏼"),
            ),
          ],
        );
      },
    );
  }

  // --- Animation Logic for Flying Emotes ---
  void _triggerEmoteBurst(BuildContext context, String emoji) {
    HapticFeedback.mediumImpact();
    final overlayState = Overlay.of(context);

    // Create an entry that holds the stack of flying emotes
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        // Create 20 particles
        return Stack(
          children: List.generate(20, (index) {
            return _FlyingEmote(emoji: emoji, index: index);
          }),
        );
      },
    );

    overlayState.insert(overlayEntry);

    // Remove the overlay after the animation duration (3 seconds)
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }
}

// --- Helper Widget for individual flying emote ---
class _FlyingEmote extends StatefulWidget {
  final String emoji;
  final int index;

  const _FlyingEmote({required this.emoji, required this.index});

  @override
  State<_FlyingEmote> createState() => _FlyingEmoteState();
}

class _FlyingEmoteState extends State<_FlyingEmote>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late double _startX;
  late double _endX;
  late double _size;

  @override
  void initState() {
    super.initState();
    final random = Random();
    const screenWidth = 400.0; // Approximation is fine for random distribution

    // Randomize physics
    _startX = random.nextDouble() * screenWidth; // Spread across width
    _endX =
        _startX + (random.nextDouble() * 100 - 50); // Slight horizontal drift
    _size = random.nextDouble() * 20 + 24; // Random Size 24-44

    final durationMs = 2000 + random.nextInt(1000); // Random duration 2s - 3s

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Fade out near the end
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)),
    );

    // Start immediately
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate upward movement (Linear or easeOut)
        // Moves from 0 (bottom) to 80% of screen height
        final currentY = screenHeight * 0.8 * _controller.value;

        // Calculate current X (Drifting)
        final currentX = _startX + (_endX - _startX) * _controller.value;

        return Positioned(
          left: currentX,
          bottom:
              -50 + currentY, // Start slightly below screen (-50) and move up
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: _size,
                decoration:
                    TextDecoration.none, // Removes yellow underline in Overlay
              ),
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------------
// --- Existing Helpers ---
// --------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsContainer extends StatelessWidget {
  final List<Widget> children;

  const _SettingsContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}
