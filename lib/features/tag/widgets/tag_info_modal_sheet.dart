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

    final theme = Theme.of(context);
    final metaProvider = Provider.of<MetaProvider>(
      passedContext,
      listen: false,
    );

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
                  child: Row(
                    children: [
                      Text(
                        "Edit Folder",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    controller: nameController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: "Folder Name",
                      hintText: "e.g. Groceries",
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.4),
                      prefixIcon: Icon(
                        Icons.label_outline_rounded,
                        color: theme.colorScheme.primary,
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
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          final updatedTag = currentTag.copyWith(name: name);

                          await metaProvider.updateTag(updatedTag);

                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
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
                            child: InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) =>
                                      AddEditFolderBudgetModalSheet(tag: tag),
                                );
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: TagBudgetCard(tag: tag),
                            ),
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

  // String _getFreqLabel(TagBudgetResetFrequency freq) {
  //   switch (freq) {
  //     case TagBudgetResetFrequency.never:
  //       return "Total";
  //     case TagBudgetResetFrequency.daily:
  //       return "Daily";
  //     case TagBudgetResetFrequency.weekly:
  //       return "Weekly";
  //     case TagBudgetResetFrequency.monthly:
  //       return "Monthly";
  //     case TagBudgetResetFrequency.quarterly:
  //       return "Quarterly";
  //     case TagBudgetResetFrequency.yearly:
  //       return "Yearly";
  //   }
  // }
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
