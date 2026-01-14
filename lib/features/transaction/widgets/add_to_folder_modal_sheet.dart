import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class AddToFolderModalSheet extends StatefulWidget {
  final MetaProvider metaProvider;
  final TransactionProvider txProvider;
  final List<Tag> initialTags;
  final ScrollController scrollController;
  final Function(List<Tag>) onSelected;

  const AddToFolderModalSheet({
    super.key,
    required this.metaProvider,
    required this.txProvider,
    required this.initialTags,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  State<AddToFolderModalSheet> createState() => _AddToFolderModalSheetState();
}

class _AddToFolderModalSheetState extends State<AddToFolderModalSheet> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  late List<Tag> _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = List.from(widget.initialTags);
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
                    'Add to Folders',
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

  void _createAndSelect(String name) async {
    final newTag = await widget.metaProvider.addTag(name);
    _toggleSelection(newTag);
    // Clear search
    _searchController.clear();
    setState(() {
      _searchQuery = "";
    });
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
          color: isSelected
              ? (tagColor ?? theme.colorScheme.primary)
              : tagColor?.withAlpha(230),
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: tagColor ?? theme.colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
