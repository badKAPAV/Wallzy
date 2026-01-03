import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final status = await Permission.sms.status;
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
      if (status.isGranted) {
        widget.onPermissionGranted?.call();
      }
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.sms.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
      if (status.isGranted) {
        widget.onPermissionGranted?.call();
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
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
                  Icons.sms_failed_outlined,
                  color: colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Permission Required",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Wallzy needs messages permission for the full effortless experience",
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
