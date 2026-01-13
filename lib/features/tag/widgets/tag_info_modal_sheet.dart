import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/tag/widgets/event_mode_settings_card.dart';
import 'package:wallzy/features/tag/widgets/tag_budget_card.dart';
import 'package:wallzy/features/tag/widgets/add_edit_folder_budget_modal_sheet.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/common/widgets/tile_data_widgets.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';

class TagInfoModalSheet extends StatefulWidget {
  final Tag tag;
  final BuildContext passedContext;

  const TagInfoModalSheet({
    super.key,
    required this.tag,
    required this.passedContext,
  });

  @override
  State<TagInfoModalSheet> createState() => _TagInfoModalSheetState();
}

class _TagInfoModalSheetState extends State<TagInfoModalSheet> {
  // --- COLOR PICKER MODAL ---
  void _showColorPickerModal(BuildContext context, Tag currentTag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final colors = Tag.defaultTagColors;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Change Folder Color",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.start,
                children: colors.map((color) {
                  final isSelected = currentTag.color == color.value;
                  return GestureDetector(
                    onTap: () async {
                      final updatedTag = currentTag.copyWith(
                        color: color.value,
                      );
                      await Provider.of<MetaProvider>(
                        widget.passedContext,
                        listen: false,
                      ).updateTag(updatedTag);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showEditTagDialog(
    BuildContext context,
    BuildContext passedContext,
    Tag currentTag,
  ) {
    final nameController = TextEditingController(text: currentTag.name);
    final budgetController = TextEditingController(
      text: currentTag.tagBudget != null && currentTag.tagBudget! > 0
          ? currentTag.tagBudget.toString()
          : '',
    );
    TagBudgetResetFrequency budgetFrequency =
        currentTag.tagBudgetFrequency ?? TagBudgetResetFrequency.never;

    final theme = Theme.of(context);
    final metaProvider = Provider.of<MetaProvider>(
      passedContext,
      listen: false,
    );

    bool isEventMode = metaProvider.isEventModeEnabled(currentTag.id);
    bool isAutoAdd = metaProvider.isAutoAddEnabled(currentTag.id);
    DateTime? startDate = currentTag.eventStartDate;
    DateTime? endDate = currentTag.eventEndDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              0,
              24,
              0,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Edit Folder",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Folder Name",
                      hintText: "e.g. Groceries",
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: budgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: "Budget (Optional)",
                            hintText: "0.0",
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.pie_chart_rounded),
                          ),
                          onChanged: (val) => setModalState(() {}),
                        ),
                      ),
                      if ((double.tryParse(budgetController.text) ?? 0) >
                          0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TagBudgetResetFrequency>(
                              value: budgetFrequency,
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              items: TagBudgetResetFrequency.values.map((e) {
                                String label = e.toString().split('.').last;
                                if (e == TagBudgetResetFrequency.never)
                                  label = "Total";
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    label[0].toUpperCase() + label.substring(1),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setModalState(() => budgetFrequency = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                SwitchListTile(
                  title: const Text("Event Mode"),
                  subtitle: const Text("Set a date range for this folder"),
                  value: isEventMode,
                  onChanged: (val) {
                    setModalState(() {
                      isEventMode = val;
                      if (isEventMode && startDate == null) {
                        startDate = DateTime.now();
                        endDate = DateTime.now().add(const Duration(days: 7));
                      }
                    });
                  },
                ),
                if (isEventMode) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDateRange: startDate != null && endDate != null
                              ? DateTimeRange(start: startDate!, end: endDate!)
                              : null,
                        );
                        if (picked != null) {
                          setModalState(() {
                            startDate = picked.start;
                            endDate = picked.end;
                          });
                        }
                      },
                      child: Text(
                        startDate != null && endDate != null
                            ? "${DateFormat.yMMMd().format(startDate!)} - ${DateFormat.yMMMd().format(endDate!)}"
                            : "Select Date Range",
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text("Auto-Add Transactions"),
                    subtitle: const Text("Txns added to folder when in range"),
                    value: isAutoAdd,
                    onChanged: (val) =>
                        setModalState(() => isAutoAdd = val ?? false),
                  ),
                ],

                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          final budget = double.tryParse(budgetController.text);
                          final updatedTag = currentTag.copyWith(
                            name: name,
                            tagBudget: budget,
                            tagBudgetFrequency: (budget ?? 0) > 0
                                ? budgetFrequency
                                : null,
                            eventStartDate: isEventMode ? startDate : null,
                            eventEndDate: isEventMode ? endDate : null,
                          );

                          await metaProvider.updateTag(updatedTag);
                          await metaProvider.setEventMode(
                            currentTag.id,
                            isEventMode,
                          );
                          await metaProvider.setAutoAddTag(
                            currentTag.id,
                            isAutoAdd,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: const Text("Save Changes"),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    BuildContext passedContext,
    Tag currentTag,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: 'Delete Folder?',
        description:
            'Are you sure you want to delete "${currentTag.name}"? This folder will be removed from all associated transactions.',
        icon: HugeIcons.strokeRoundedDelete02,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<MetaProvider>(
                passedContext,
                listen: false,
              ).deleteTag(currentTag.id);
              if (context.mounted) Navigator.pop(context);
              if (passedContext.mounted) Navigator.pop(passedContext);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<MetaProvider>(
      builder: (context, metaProvider, child) {
        final tag = metaProvider.tags.firstWhere(
          (t) => t.id == widget.tag.id,
          orElse: () => widget.tag,
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      children: [
                        _TagVisualCard(tag: tag),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ActionBox(
                                label: "Edit",
                                icon: Icons.edit_rounded,
                                color: colorScheme.secondary,
                                onTap: () => _showEditTagDialog(
                                  context,
                                  widget.passedContext,
                                  tag,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ActionBox(
                                label: "Delete",
                                icon: Icons.delete_outline_rounded,
                                color: colorScheme.error,
                                onTap: () => _showDeleteConfirmation(
                                  context,
                                  widget.passedContext,
                                  tag,
                                ),
                                isDestructive: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Folder Details",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (tag.tagBudget != null && tag.tagBudget! > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TagBudgetCard(tag: tag),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SetBudgetPromptSheet(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) =>
                                      AddEditFolderBudgetModalSheet(tag: tag),
                                );
                              },
                            ),
                          ),
                        EventModeSettingsCard(tag: tag),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: Row(
                            children: [
                              Expanded(
                                child: DataTile(
                                  label: "Folder Name",
                                  value: tag.name,
                                  icon: HugeIcons.strokeRoundedFolder02,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DataTile(
                                  label: "Budget Cycle",
                                  value: tag.tagBudgetFrequency != null
                                      ? _getFreqLabel(tag.tagBudgetFrequency!)
                                      : "None",
                                  icon: HugeIcons.strokeRoundedPieChart02,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      _showColorPickerModal(context, tag),
                                  borderRadius: BorderRadius.circular(20),
                                  child: DataTile(
                                    color: tag.color != null
                                        ? Color(tag.color!)
                                        : colorScheme.primary,
                                    label: "Folder Color",
                                    value: "Tap to change",
                                    icon: Icons.palette_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DataTile(
                                  label: "Date Created",
                                  value: DateFormat.yMMMd().format(
                                    tag.createdAt,
                                  ),
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  String _getFreqLabel(TagBudgetResetFrequency freq) {
    switch (freq) {
      case TagBudgetResetFrequency.never:
        return "Total";
      case TagBudgetResetFrequency.daily:
        return "Daily";
      case TagBudgetResetFrequency.weekly:
        return "Weekly";
      case TagBudgetResetFrequency.monthly:
        return "Monthly";
      case TagBudgetResetFrequency.quarterly:
        return "Quarterly";
      case TagBudgetResetFrequency.yearly:
        return "Yearly";
    }
  }
}

class _TagVisualCard extends StatelessWidget {
  final Tag tag;
  const _TagVisualCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color tagColor = tag.color != null
        ? Color(tag.color!)
        : colorScheme.primary;

    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tagColor.withAlpha(200), tagColor.withAlpha(255)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tagColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedFolder02,
              color: Colors.white,
              size: 20,
            ),
          ),
          Text(
            tag.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SetBudgetPromptSheet extends StatelessWidget {
  final VoidCallback onTap;
  const _SetBudgetPromptSheet({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPieChart02,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Set a Folder Budget",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Track spending limits",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
