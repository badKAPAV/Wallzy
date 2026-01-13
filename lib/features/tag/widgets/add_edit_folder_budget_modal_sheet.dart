import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
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

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
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
          // Drag Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPieChart02,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tag.tagBudget != null && widget.tag.tagBudget! > 0
                          ? "Edit Budget"
                          : "Set Budget",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedFolder02,
                          size: 12,
                          strokeWidth: 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.tag.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Budget Input
          TextField(
            controller: _budgetController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            decoration: InputDecoration(
              hintText: "0.0",
              labelText: "Limit",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              // prefixIcon: const Icon(Icons.attach_money_rounded),
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),

          const SizedBox(height: 24),

          // Frequency Selection
          Text(
            "Budget Reset Frequency",
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: TagBudgetResetFrequency.values.map((f) {
              final isSelected = _frequency == f;
              String label;
              switch (f) {
                case TagBudgetResetFrequency.never:
                  label = 'Never';
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

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _frequency = f);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                showCheckmark: false,
                selectedColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _budgetController.text.isEmpty
                  ? null
                  : () async {
                      final amount = double.tryParse(_budgetController.text);
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
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Save Budget",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
