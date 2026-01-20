import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/models/account.dart'; // Needed for Account Picker
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart'; // Needed for Create Account

class AmountInputHero extends StatelessWidget {
  final TextEditingController controller;
  final Color color;

  const AmountInputHero({
    super.key,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settingsProvider.currencySymbol,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: color.withAlpha(204),
                height: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                // Simple validation to ensure non-empty
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DatePill extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const DatePill({super.key, required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    bool isTomorrow =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day + 1;

    String dateLabel = isToday
        ? "Today"
        : isTomorrow
        ? "Tomorrow"
        : DateFormat('MMM d, yyyy').format(selectedDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FunkyPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final IconData? valueIcon;
  final Widget? leadingValueWidget;
  final Color? valueColor;
  final Widget? valueWidget;
  final VoidCallback onTap;
  final bool isError;
  final bool isCompact;
  final Widget? trailingAction;

  const FunkyPickerTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.valueIcon,
    this.leadingValueWidget,
    this.valueColor,
    this.valueWidget,
    required this.onTap,
    this.isError = false,
    this.isCompact = false,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 4 : 12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isError ? Border.all(color: colorScheme.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isError ? colorScheme.error : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      (valueWidget == null &&
                          (value != null ||
                              valueIcon != null ||
                              leadingValueWidget != null))
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: _buildValuePill(context),
                        )
                      : const SizedBox.shrink(),
                ),
                if (trailingAction != null)
                  trailingAction!
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant.withAlpha(128),
                    size: 20,
                  ),
              ],
            ),
            if (valueWidget != null) ...[
              const SizedBox(height: 8),
              valueWidget!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValuePill(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pillColor = valueColor ?? colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pillColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingValueWidget != null) ...[
            leadingValueWidget!,
            const SizedBox(width: 6),
          ] else if (valueIcon != null) ...[
            Icon(valueIcon, size: 16, color: pillColor),
            const SizedBox(width: 6),
          ],
          if (value != null)
            Flexible(
              child: Text(
                value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: pillColor,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class FunkyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const FunkyTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        prefixIcon: icon != null
            ? Icon(icon, color: colorScheme.outline)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// --- NEW HELPERS ---

class PickerItem {
  final String id;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  PickerItem({
    required this.id,
    required this.label,
    required this.icon,
    this.subtitle,
    this.color,
  });
}

Future<String?> showModernPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  String? selectedId,
  bool showCreateNew = false,
  VoidCallback? onCreateNew,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, controller) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showCreateNew && onCreateNew != null)
                      IconButton.filledTonal(
                        onPressed: onCreateNew,
                        icon: const Icon(Icons.add),
                        tooltip: 'Create New',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    controller: controller,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final isSelected = item.id == selectedId;
                      final baseColor =
                          item.color ?? Theme.of(context).colorScheme.primary;

                      return InkWell(
                        onTap: () => Navigator.pop(ctx, item.id),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? baseColor.withOpacity(0.15)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? baseColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? baseColor
                                      : Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: isSelected ? Colors.white : baseColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? baseColor
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? baseColor.withAlpha(204)
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void showCustomAccountModal(
  BuildContext context,
  List<Account> accounts,
  Function(Account) onSelect, {
  String? selectedId,
}) async {
  final resultId = await showModernPickerSheet(
    context: context,
    title: 'Select Account',
    showCreateNew: true,
    onCreateNew: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
      );
    },
    items: accounts
        .map(
          (acc) => PickerItem(
            id: acc.id,
            label: acc.bankName,
            subtitle: acc.accountNumber,
            icon: acc.bankName.toLowerCase() == 'cash'
                ? Icons.payments_rounded
                : Icons.account_balance_rounded,
            color: acc.accountType == 'credit'
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        )
        .toList(),
    selectedId: selectedId,
  );

  if (resultId != null) {
    // Note: Assuming accounts list is not empty or ID is valid
    try {
      final acc = accounts.firstWhere((a) => a.id == resultId);
      onSelect(acc);
    } catch (_) {}
  }
}
