import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';

class AddEditFolderBudgetModalSheet extends StatefulWidget {
  final Tag tag;

  const AddEditFolderBudgetModalSheet({super.key, required this.tag});

  @override
  State<AddEditFolderBudgetModalSheet> createState() =>
      _AddEditFolderBudgetModalSheetState();
}

class _AddEditFolderBudgetModalSheetState
    extends State<AddEditFolderBudgetModalSheet> {
  late TextEditingController _budgetController;
  late TagBudgetResetFrequency _frequency;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: widget.tag.tagBudget != null && widget.tag.tagBudget! > 0
          ? widget.tag.tagBudget!.toStringAsFixed(0)
          : '',
    );
    _frequency =
        widget.tag.tagBudgetFrequency ?? TagBudgetResetFrequency.monthly;
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final currency = context.read<SettingsProvider>().currencySymbol;

    return Container(
      padding: EdgeInsets.fromLTRB(
        0,
        24,
        0,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPieChart02,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tag.tagBudget != null &&
                                widget.tag.tagBudget! > 0
                            ? "Edit Budget"
                            : "Set Budget",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedFolder02,
                            size: 12,
                            strokeWidth: 2,
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.7,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.tag.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant.withOpacity(
                                0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Budget Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              controller: _budgetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'momo',
              ),
              decoration: InputDecoration(
                hintText: "0.0",
                labelText: "Budget Limit",
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontFamily: 'momo',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
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
                suffixIcon: _budgetController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() => _budgetController.clear());
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 32),

          // Frequency Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "Reset Frequency",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: TagBudgetResetFrequency.values.map((f) {
                final isSelected = _frequency == f;
                String label;
                switch (f) {
                  case TagBudgetResetFrequency.never:
                    label = 'Total';
                    break;
                  case TagBudgetResetFrequency.daily:
                    label = 'Daily';
                    break;
                  case TagBudgetResetFrequency.weekly:
                    label = 'Weekly';
                    break;
                  case TagBudgetResetFrequency.monthly:
                    label = 'Monthly';
                    break;
                  case TagBudgetResetFrequency.quarterly:
                    label = 'Quarterly';
                    break;
                  case TagBudgetResetFrequency.yearly:
                    label = 'Yearly';
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _frequency = f);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withOpacity(0.5),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    showCheckmark: false,
                    selectedColor: colorScheme.primary.withOpacity(0.12),
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 40),

          // Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: () async {
                  final budgetText = _budgetController.text;
                  final amount = budgetText.isEmpty
                      ? 0.0
                      : double.tryParse(budgetText);

                  if (amount != null) {
                    final updatedTag = widget.tag.copyWith(
                      tagBudget: amount,
                      tagBudgetFrequency: amount > 0 ? _frequency : null,
                    );

                    await Provider.of<MetaProvider>(
                      context,
                      listen: false,
                    ).updateTag(updatedTag);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  backgroundColor: _budgetController.text.isEmpty
                      ? colorScheme.errorContainer.withOpacity(0.5)
                      : colorScheme.primary,
                  foregroundColor: _budgetController.text.isEmpty
                      ? colorScheme.error
                      : colorScheme.onPrimary,
                ),
                child: Text(
                  _budgetController.text.isEmpty
                      ? "Remove Budget"
                      : "Save Budget",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
