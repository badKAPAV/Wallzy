import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ModernAlertDialog extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;
  final Color? iconColor; // Optional: Defaults to primary
  final List<Widget> actions;

  const ModernAlertDialog({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.actions,
    this.iconColor,
  });

  /// Helper method to show the dialog easily
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String description,
    required dynamic icon,
    required List<Widget> actions,
    Color? iconColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ModernAlertDialog(
        title: title,
        description: description,
        icon: icon,
        actions: actions,
        iconColor: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = iconColor ?? colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent, // We handle the background
      insetPadding: const EdgeInsets.all(
        24,
      ), // Breathing room from screen edges
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer, // M3 Dialog Background
          borderRadius: BorderRadius.circular(28), // M3 Standard Radius
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content height
            children: [
              // 1. Icon Section with Glow
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 32, color: activeColor),
              ),
              const SizedBox(height: 20),

              // 2. Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5, // Better readability
                ),
              ),
              const SizedBox(height: 32),

              // 4. Actions (Stacked or Row based on count)
              // If actions > 2, we usually stack them. If 2, we put them in a row.
              if (actions.length > 2)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: a,
                        ),
                      )
                      .toList(),
                )
              else
                Row(
                  children: actions.map((widget) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: actions.indexOf(widget) == 0 ? 0 : 8.0,
                          right: actions.indexOf(widget) == actions.length - 1
                              ? 0
                              : 8.0,
                        ),
                        child: widget,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
