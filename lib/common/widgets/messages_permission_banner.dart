import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class MessagesPermissionBanner extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  /// Set this to true to force the banner to show for UI testing
  final bool debugForceShow;

  final bool isSmall;

  const MessagesPermissionBanner({
    super.key,
    this.onPermissionGranted,
    this.debugForceShow = false,
    this.isSmall = false,
  });

  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  static Future<bool> checkPermission() async {
    try {
      return await _platform.invokeMethod('isNotificationListenerEnabled');
    } catch (e) {
      debugPrint("Error checking notification listener status static: $e");
      return false;
    }
  }

  @override
  State<MessagesPermissionBanner> createState() =>
      _MessagesPermissionBannerState();
}

class _MessagesPermissionBannerState extends State<MessagesPermissionBanner>
    with WidgetsBindingObserver {
  bool _hasPermission = true; // Assume true initially to avoid flicker

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

  Future<void> _checkPermission() async {
    try {
      final bool realStatus = await MessagesPermissionBanner.checkPermission();

      // LOGIC CHANGE: If debugForceShow is true, we act as if we DON'T have permission
      final bool effectiveStatus = widget.debugForceShow ? false : realStatus;

      if (mounted) {
        setState(() {
          _hasPermission = effectiveStatus;
        });

        // Only trigger callback if we REALLY have permission and aren't forcing debug
        if (effectiveStatus) {
          widget.onPermissionGranted?.call();
        }
      }
    } catch (e) {
      debugPrint("Error checking notification listener status: $e");
    }
  }

  Future<void> _openListenerSettings() async {
    try {
      // Closes the dialog first
      Navigator.of(context).pop();
      await MessagesPermissionBanner._platform.invokeMethod(
        'openNotificationListenerSettings',
      );
    } catch (e) {
      debugPrint("Error opening notification settings: $e");
    }
  }

  Future<void> _openAppInfo() async {
    try {
      // Closes the dialog first
      Navigator.of(context).pop();
      // Ensure your Kotlin/Java MainActivity handles 'openAppInfo'
      await MessagesPermissionBanner._platform.invokeMethod('openAppInfo');
    } catch (e) {
      debugPrint("Error opening app info: $e");
    }
  }

  void _showInstructionDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text("Enable AutoLog"),
            const SizedBox(width: 4),
            HugeIcon(
              icon: HugeIcons.strokeRoundedMenu03,
              strokeWidth: 3,
              size: 24,
              color: colorScheme.primary,
            ),
          ],
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Step 1: Standard Instruction ---
            _InstructionStep(
              number: "1",
              text:
                  "Tap the 'Go to Settings' button below. Scroll down and find 'Ledgr' in the list.",
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _InstructionStep(
              number: "2",
              text: "Turn the switch ON to allow notification access.",
              colorScheme: colorScheme,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(),
            ),

            // --- Step 2: Restricted Settings (Troubleshooting) ---
            Text(
              "Is the switch greyed out?",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Android sometimes restricts this permission for downloaded apps. To fix this:",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _InstructionStep(
              number: "A",
              text:
                  "Tap the 'Open App Info' button below. Go to 'Permissions'.",
              colorScheme: colorScheme,
              isSubStep: true,
            ),
            const SizedBox(height: 8),
            _InstructionStep(
              number: "B",
              text: "Tap the 3 dots (top right) → 'Allow Restricted Settings'.",
              colorScheme: colorScheme,
              isSubStep: true,
            ),
            const SizedBox(height: 8),
            _InstructionStep(
              number: "C",
              text: "Come back here and try enabling access again.",
              colorScheme: colorScheme,
              isSubStep: true,
            ),

            const SizedBox(height: 24),

            // --- Privacy Assurance ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Ledgr processes all data on-device. No personal data is saved or uploaded other than your transaction records.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Button 1: App Info (Troubleshooting)
          TextButton(
            onPressed: _openAppInfo,
            child: const Text("Open App Info"),
          ),
          // Button 2: The Main Action
          FilledButton(
            onPressed: _openListenerSettings,
            child: const Text("Go to Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isSmall) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showInstructionDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Turn on AutoLog",
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMenu03,
                  strokeWidth: 3,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showInstructionDialog,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Turn on AutoLog",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedMenu03,
                            strokeWidth: 3,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          // Icon(Icons.auto_awesome_rounded, size: 12),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Grant notification access to instantly log your spends. Tap to see how to enable it securely.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper Widget for clean dialog code
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  final ColorScheme colorScheme;
  final bool isSubStep;

  const _InstructionStep({
    required this.number,
    required this.text,
    required this.colorScheme,
    this.isSubStep = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSubStep
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSubStep
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
