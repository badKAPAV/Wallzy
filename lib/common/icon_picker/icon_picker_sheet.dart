import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/icon_picker/icons.dart';

class GoalIconPickerSheet extends StatelessWidget {
  final String? selectedIconKey;
  final Function(String) onIconSelected;

  const GoalIconPickerSheet({
    super.key,
    required this.selectedIconKey,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = GoalIconRegistry.keys;

    return Container(
      height: 500, // Or use constraints
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Icon',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 5 icons per row
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final iconData = GoalIconRegistry.getIcon(key);
                final isSelected =
                    key == (selectedIconKey ?? GoalIconRegistry.defaultKey);

                return InkWell(
                  onTap: () {
                    onIconSelected(key);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: HugeIcon(
                      icon: iconData,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
