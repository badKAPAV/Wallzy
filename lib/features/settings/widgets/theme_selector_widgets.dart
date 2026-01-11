import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeSelector({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width / 3;

          return Stack(
            children: [
              // 1. The Animated Background Indicator
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _getAlignment(currentMode),
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. The Tap Targets (Icons + Text)
              Row(
                children: [
                  _ThemeTab(
                    label: "System",
                    icon: Icons.brightness_auto_rounded,
                    isSelected: currentMode == ThemeMode.system,
                    onTap: () => onThemeChanged(ThemeMode.system),
                  ),
                  _ThemeTab(
                    label: "Light",
                    icon: Icons.light_mode_rounded,
                    isSelected: currentMode == ThemeMode.light,
                    onTap: () => onThemeChanged(ThemeMode.light),
                  ),
                  _ThemeTab(
                    label: "Dark",
                    icon: Icons.dark_mode_rounded,
                    isSelected: currentMode == ThemeMode.dark,
                    onTap: () => onThemeChanged(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Alignment _getAlignment(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Alignment.centerLeft;
      case ThemeMode.light:
        return Alignment.center;
      case ThemeMode.dark:
        return Alignment.centerRight;
    }
  }
}

class _ThemeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTab({
    // super.key, // Added super.key for best practice
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Grab a base style from your theme (which has Inter)
    final baseStyle = theme.textTheme.labelMedium;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          // 2. Use copyWith to keep the font family while changing color
          style:
              baseStyle?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize:
                    12, // Explicit size if needed, or rely on labelMedium default
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ) ??
              const TextStyle(), // Fallback if theme is null
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
              ), // Text will now inherit the AnimatedDefaultTextStyle above
            ],
          ),
        ),
      ),
    );
  }
}
