import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/accounts/models/account.dart'; // Needed for Account Picker
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart'; // Needed for Create Account

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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹',
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
  final VoidCallback onTap;
  final bool isError;
  final bool isCompact;

  const FunkyPickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isError = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: isError
                ? Border.all(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value == null
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha(128),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isError
              ? Border.all(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? "Select",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class FunkyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofocus: autofocus,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(
                hintText: label,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
              onChanged: onChanged,
              onFieldSubmitted: onFieldSubmitted,
            ),
          ),
        ],
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
