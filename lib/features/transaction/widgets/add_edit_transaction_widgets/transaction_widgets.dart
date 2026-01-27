import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

enum TransactionMode { expense, income, transfer }

// ==============================================================================
// ==========================  SHARED & HELPER WIDGETS  =========================
// ==============================================================================

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
    final currencySymbol = settingsProvider.currencySymbol;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currencySymbol,
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
                autofocus: true,
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
                validator: (v) =>
                    v == null || v.isEmpty || double.tryParse(v) == 0
                    ? ''
                    : null,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
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
              DateTime.now().year == selectedDate.year &&
                      DateTime.now().month == selectedDate.month &&
                      DateTime.now().day == selectedDate.day
                  ? 'Today'
                  : DateFormat('MMM d, yyyy').format(selectedDate),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimePill extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const TimePill({super.key, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              time.format(context),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionActionChip extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;

  const TransactionActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: icon,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactAccountPill extends StatelessWidget {
  final String accountName;
  final String methodName;
  final VoidCallback onTap;

  const CompactAccountPill({
    super.key,
    required this.accountName,
    required this.methodName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wallet_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              "$accountName • $methodName",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final IconData icon;
  const FunkyTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        prefixIcon: Icon(icon, color: colorScheme.outline),
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
    final acc = accounts.firstWhere((a) => a.id == resultId);
    onSelect(acc);
  }
}

class FolderPickerSheet extends StatefulWidget {
  final MetaProvider metaProvider;
  final TransactionProvider txProvider;
  final List<Tag> selectedFolders;
  final ScrollController scrollController;
  final Function(List<Tag>) onSelected;

  const FolderPickerSheet({
    super.key,
    required this.metaProvider,
    required this.txProvider,
    required this.selectedFolders,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  late List<Tag> _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = List.from(widget.selectedFolders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(Tag tag) {
    setState(() {
      if (_currentSelection.any((t) => t.id == tag.id)) {
        _currentSelection.removeWhere((t) => t.id == tag.id);
      } else {
        _currentSelection.add(tag);
      }
    });
  }

  void _submit() {
    widget.onSelected(_currentSelection);
    Navigator.pop(context);
  }

  void _createAndSelect(String name) async {
    final newTag = await widget.metaProvider.addTag(name);
    _toggleSelection(newTag);
    _searchController.clear();
    setState(() {
      _searchQuery = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = widget.metaProvider.searchTags(_searchQuery);
    final mostUsed = widget.txProvider.getMostUsedTags(limit: 4);
    final recent = widget.txProvider.getRecentTags(limit: 4);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withAlpha(128),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Folders',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _submit,
                  child: Text(
                    "Done (${_currentSelection.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: "Search or create a folder",
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 10,
                      strokeWidth: 2,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _createAndSelect(v.trim());
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          Flexible(
            child: ListView(
              controller: widget.scrollController,
              shrinkWrap: false,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (_searchQuery.isEmpty) ...[
                  if (recent.isNotEmpty) ...[
                    _buildSectionHeader(theme, "RECENTLY USED"),
                    const SizedBox(height: 8),
                    _FolderChips(
                      tags: recent,
                      selectedIds: _currentSelection.map((e) => e.id).toSet(),
                      onTap: _toggleSelection,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (mostUsed.isNotEmpty) ...[
                    _buildSectionHeader(theme, "MOST USED"),
                    const SizedBox(height: 8),
                    _FolderChips(
                      tags: mostUsed,
                      selectedIds: _currentSelection.map((e) => e.id).toSet(),
                      onTap: _toggleSelection,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildSectionHeader(theme, "ALL FOLDERS"),
                  const SizedBox(height: 8),
                  if (widget.metaProvider.tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No folders created yet",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ...widget.metaProvider.tags.map(
                    (t) => _FolderListTile(
                      tag: t,
                      isSelected: _currentSelection.any((s) => s.id == t.id),
                      onTap: () => _toggleSelection(t),
                    ),
                  ),
                ] else ...[
                  if (suggestions.isNotEmpty)
                    ...suggestions.map(
                      (t) => _FolderListTile(
                        tag: t,
                        isSelected: _currentSelection.any((s) => s.id == t.id),
                        onTap: () => _toggleSelection(t),
                      ),
                    ),
                  if (!suggestions.any(
                    (t) =>
                        t.name.toLowerCase() ==
                        _searchQuery.trim().toLowerCase(),
                  ))
                    ListTile(
                      leading: Icon(
                        Icons.add_circle_outline_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        "Create \"$_searchQuery\"",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => _createAndSelect(_searchQuery.trim()),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _FolderChips extends StatelessWidget {
  final List<Tag> tags;
  final Set<String> selectedIds;
  final Function(Tag) onTap;

  const _FolderChips({
    required this.tags,
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: tags.map((t) {
        final isSelected = selectedIds.contains(t.id);
        final Color? tagColor = t.color != null ? Color(t.color!) : null;
        return ActionChip(
          avatar: isSelected
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                )
              : Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: tagColor ?? Theme.of(context).colorScheme.primary,
                ),
          label: Text(t.name),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (tagColor != null
                      ? tagColor.withAlpha(230)
                      : Theme.of(context).colorScheme.onSurface),
          ),
          padding: EdgeInsets.zero,
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : (tagColor != null
                    ? tagColor.withOpacity(0.08)
                    : Theme.of(context).colorScheme.surfaceContainerHighest),
          side: isSelected
              ? BorderSide(color: Theme.of(context).colorScheme.primary)
              : (tagColor != null
                    ? BorderSide(color: tagColor.withAlpha(50))
                    : BorderSide.none),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () => onTap(t),
        );
      }).toList(),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final Tag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderListTile({
    required this.tag,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? tagColor = tag.color != null ? Color(tag.color!) : null;
    return ListTile(
      leading: Icon(
        Icons.folder_rounded,
        color: isSelected
            ? (tagColor ?? theme.colorScheme.primary)
            : (tagColor?.withAlpha(179) ?? theme.colorScheme.outline),
        size: 20,
      ),
      title: Text(
        tag.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
