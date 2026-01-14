// lib/features/home/screens/folder_selection_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/dashboard/provider/home_widgets_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';

class FolderSelectionSheet extends StatefulWidget {
  final String widgetId;
  final List<String> initialSelection;

  const FolderSelectionSheet({
    super.key,
    required this.widgetId,
    this.initialSelection = const [],
  });

  @override
  State<FolderSelectionSheet> createState() => _FolderSelectionSheetState();
}

class _FolderSelectionSheetState extends State<FolderSelectionSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelection);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < 3) {
          _selectedIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You can only choose up to 3 folders"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Select Folders",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Choose up to 3 folders to monitor\nYou can only monitor folders with a set budget",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 16),

          // List of Folders
          Expanded(
            child: Consumer<MetaProvider>(
              builder: (context, metaProvider, _) {
                final tags = metaProvider.tags
                    .where((t) => t.tagBudget != null && (t.tagBudget ?? 0) > 0)
                    .toList();

                if (tags.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedTag01,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No folders found.\nCreate some first",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final id = tag.id;
                    final isSelected = _selectedIds.contains(id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _toggleSelection(id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer
                                      .withOpacity(0.4)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedFolder02,
                                color: tag.color != null
                                    ? Color(tag.color!)
                                    : (isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tag.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      Provider.of<HomeWidgetsProvider>(
                        context,
                        listen: false,
                      ).updateWidgetConfig(widget.widgetId, _selectedIds);
                      Navigator.pop(context);
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("Save Widget"),
            ),
          ),
        ],
      ),
    );
  }
}
