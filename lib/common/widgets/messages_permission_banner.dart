import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessagesPermissionBanner extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const MessagesPermissionBanner({super.key, this.onPermissionGranted});

  @override
  State<MessagesPermissionBanner> createState() =>
      _MessagesPermissionBannerState();
}

class _MessagesPermissionBannerState extends State<MessagesPermissionBanner>
    with WidgetsBindingObserver {
  bool _hasPermission = true; // Assume true initially to avoid flicker
  static const _platform = MethodChannel('com.example.wallzy/sms');

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
      final bool isEnabled = await _platform.invokeMethod(
        'isNotificationListenerEnabled',
      );
      if (mounted) {
        setState(() {
          _hasPermission = isEnabled;
        });
        if (isEnabled) {
          widget.onPermissionGranted?.call();
        }
      }
    } catch (e) {
      debugPrint("Error checking notification listener status: $e");
    }
  }

  Future<void> _requestPermission() async {
    try {
      await _platform.invokeMethod('openNotificationListenerSettings');
      // No immediate state change; wait for resume
    } catch (e) {
      debugPrint("Error opening notification settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _requestPermission,
          borderRadius: BorderRadius.circular(16),
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
                      Text(
                        "Enable Auto-Tracking",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Wallzy needs notification access to detect bank transaction alerts and help you automatically log expenses. We do not read personal chats or other notifications.",
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
