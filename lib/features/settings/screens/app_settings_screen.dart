import 'dart:async';
import 'dart:math'; // For randomizing animations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/common/widgets/messages_permission_banner.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/screens/currency_selection_screen.dart';

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

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    Widget betaTag() {
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

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: false),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          const MessagesPermissionBanner(),

          _SectionHeader(title: "Display"),
          const SizedBox(height: 8),
          _SettingsContainer(
            children: [
              _ThemeRadioTile(
                title: "System Default",
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (val) => themeProvider.setThemeMode(val!),
                icon: Icons.brightness_auto,
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant.withAlpha(128),
              ),
              _ThemeRadioTile(
                title: "Light Mode",
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (val) => themeProvider.setThemeMode(val!),
                icon: Icons.light_mode,
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant.withAlpha(128),
              ),
              _ThemeRadioTile(
                title: "Dark Mode",
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (val) => themeProvider.setThemeMode(val!),
                icon: Icons.dark_mode,
              ),
            ],
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
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.5,
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
                              if (day != null)
                                settings.setBudgetCycleStartDay(day);
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
                  return SwitchListTile.adaptive(
                    value: settings.autoRecordTransactions,
                    onChanged: (val) => settings.setAutoRecordTransactions(val),
                    title: Text(
                      "Auto Save Transactions",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Automatically save pending SMS transactions on app launch",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        betaTag(),
                      ],
                    ),
                    secondary: Icon(
                      Icons.bolt_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    activeThumbColor: theme.colorScheme.primary,
                    activeTrackColor: theme.colorScheme.primaryContainer,
                    inactiveThumbColor: theme.colorScheme.outline,
                    inactiveTrackColor:
                        theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  authProvider.signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
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
            "The ledgr Promise",
            style: TextStyle(fontFamily: 'momo', fontWeight: FontWeight.w600),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Look, I built ledgr because I was broke, lazy, and tired of wondering where my money went. This is a passion project, not a mega-corporation data vacuum.",
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                "• All parsing happens ON YOUR DEVICE.\n• I don't see your OTPs, your chats, or your late-night food cravings.\n• We only save the math (expenses) you approve.",
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                "Notification access sounds scary, but it's just so I can save you and me the effort of typing. That's it. Pinky promise. 🥺",
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
                _triggerEmoteBurst(context, "💀");
              },
              child: const Text("Sus but works 😏"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerEmoteBurst(context, "💖");
              },
              child: const Text("I understand 🥰"),
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
    final screenWidth = 400.0; // Approximation is fine for random distribution

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

class _ThemeRadioTile extends StatelessWidget {
  final String title;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode?> onChanged;
  final IconData icon;

  const _ThemeRadioTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final theme = Theme.of(context);

    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            icon,
            size: 20,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      activeColor: theme.colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      controlAffinity: ListTileControlAffinity.trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
