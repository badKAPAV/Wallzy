// A square/rectangular tile for displaying a single piece of data
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class DataTile extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final bool isCopyable;
  final Color? color;

  const DataTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isCopyable = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, size: 20, color: color ?? colorScheme.primary);
    } else {
      iconWidget = HugeIcon(
        icon: icon,
        size: 20,
        color: color ?? colorScheme.primary,
        strokeWidth: 2.0,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer, // M3 Container color
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color ?? colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconWidget,
              if (isCopyable)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 0),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// The Action Button Box
class ActionBox extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const ActionBox({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isDestructive
        ? color.withOpacity(0.1)
        : theme.colorScheme.surfaceContainerHighest;

    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, color: color, size: 22);
    } else {
      iconWidget = HugeIcon(
        icon: icon,
        color: color,
        size: 22,
        strokeWidth: 2.0,
      );
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
