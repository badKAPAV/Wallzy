import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';
import 'package:wallzy/features/dashboard/models/home_widget_model.dart';
import 'package:wallzy/features/dashboard/provider/home_widgets_provider.dart';
import 'package:wallzy/features/dashboard/home_widgets/folder_watchlist/folder_watchlist_widget.dart';
import 'package:wallzy/features/dashboard/home_widgets/folder_watchlist/folder_selection_sheet.dart';

class HomeWidgetsSection extends StatelessWidget {
  const HomeWidgetsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeWidgetsProvider>(
      builder: (context, provider, _) {
        final widgets = provider.activeWidgets;

        // 1. If no widgets, show the big "Add" button
        if (widgets.isEmpty) {
          return _AddWidgetButton(
            widthTiles: 4,
            heightTiles: 1,
            isFullWidth: true,
            onTap: () => _showWidgetTypeSheet(context),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            const double spacing = 12.0;
            final double tileWidth = (maxWidth - (3 * spacing)) / 4;

            double getWidgetWidth(int tiles) =>
                (tiles * tileWidth) + ((tiles - 1) * spacing);

            // pack widgets into rows of 4 columns.
            List<Widget> rows = [];
            List<Widget> currentRowChildren = [];
            int currentRowUsedWidth = 0;

            for (var widgetModel in widgets) {
              // Check if widget fits in current row
              if (currentRowUsedWidth + widgetModel.width > 4) {
                // Fill remaining space in PREVIOUS row with "Add" button if space exists
                final bool canAddMore = !widgets.any(
                  (w) => w.type == HomeWidgetType.folderWatchlist,
                );
                if (currentRowUsedWidth < 4 && canAddMore) {
                  final addWidthTiles = 4 - currentRowUsedWidth;
                  currentRowChildren.add(
                    SizedBox(
                      width: getWidgetWidth(addWidthTiles),
                      child: _AddWidgetButton(
                        widthTiles: addWidthTiles,
                        heightTiles: 2,
                        onTap: () => _showWidgetTypeSheet(context),
                      ),
                    ),
                  );
                }

                // Push the completed row
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: currentRowChildren,
                  ),
                );
                rows.add(const SizedBox(height: spacing));

                // Reset for new row
                currentRowChildren = [];
                currentRowUsedWidth = 0;
              }

              // Add the widget to current row
              currentRowChildren.add(
                SizedBox(
                  width: getWidgetWidth(widgetModel.width),
                  child: _WidgetContainer(model: widgetModel),
                ),
              );

              // Add spacing if it's NOT the end of a row
              if (currentRowUsedWidth + widgetModel.width < 4) {
                currentRowChildren.add(const SizedBox(width: spacing));
              }

              currentRowUsedWidth += widgetModel.width;

              // If row is now perfectly full, push it immediately
              if (currentRowUsedWidth == 4) {
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: currentRowChildren,
                  ),
                );
                currentRowChildren = [];
                currentRowUsedWidth = 0;
              }
            }

            // Handle Remaining Row or End-of-List "Add" button
            final bool canAddMore = !widgets.any(
              (w) => w.type == HomeWidgetType.folderWatchlist,
            );

            if (currentRowChildren.isNotEmpty) {
              // If we have a partial row, fill it with an "Add" button and push
              if (canAddMore) {
                final addWidthTiles = 4 - currentRowUsedWidth;
                currentRowChildren.add(
                  SizedBox(
                    width: getWidgetWidth(addWidthTiles),
                    child: _AddWidgetButton(
                      widthTiles: addWidthTiles,
                      heightTiles: 2,
                      onTap: () => _showWidgetTypeSheet(context),
                    ),
                  ),
                );
              }
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: currentRowChildren,
                ),
              );
            } else {
              // If perfect grid, add a slim "Add" row at bottom for continuity
              if (canAddMore) {
                if (rows.isNotEmpty) {
                  rows.add(const SizedBox(height: spacing));
                }
                rows.add(
                  _AddWidgetButton(
                    widthTiles: 4,
                    heightTiles: 1,
                    isFullWidth: true,
                    compact: true,
                    onTap: () => _showWidgetTypeSheet(context),
                  ),
                );
              }
            }

            return Column(children: rows);
          },
        );
      },
    );
  }

  void _showWidgetTypeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: false,
      builder: (_) => const WidgetSelectionSheet(),
    );
  }
}

// --- WIDGET CONTAINER (The Actual Widget Wrapper) ---
class _WidgetContainer extends StatelessWidget {
  final HomeWidgetModel model;
  const _WidgetContainer({required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.lightImpact();
        _showOptionsSheet(context, model);
      },
      onTap: model.needsSetup
          ? () => _showFolderSelectionSheet(context, model)
          : null, // Tapping an active widget could open the folder details
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 160, // Fixed height for 2 tiles (approx)
        decoration: BoxDecoration(
          color: model.needsSetup
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: model.needsSetup
            ? _buildSetupState(theme)
            : _buildWidgetContent(model),
      ),
    );
  }

  Widget _buildWidgetContent(HomeWidgetModel model) {
    switch (model.type) {
      case HomeWidgetType.folderWatchlist:
        return FolderWatchlistWidget(model: model);
      default:
        return const Center(child: Text("Coming Soon"));
    }
  }

  Widget _buildSetupState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedFolder02,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          "Setup Watchlist",
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showOptionsSheet(BuildContext context, HomeWidgetModel model) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Edit widget",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Change widget properties",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFolderSelectionSheet(context, model);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text(
                  "Remove widget",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Provider.of<HomeWidgetsProvider>(
                    context,
                    listen: false,
                  ).removeWidget(model.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderSelectionSheet(BuildContext context, HomeWidgetModel model) {
    // This sheet logic is defined below
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FolderSelectionSheet(
        widgetId: model.id,
        initialSelection: model.configIds,
      ),
    );
  }
}

// --- THE ADD BUTTON ---
class _AddWidgetButton extends StatelessWidget {
  final int widthTiles;
  final int heightTiles;
  final bool isFullWidth;
  final bool compact;
  final VoidCallback onTap;

  const _AddWidgetButton({
    required this.widthTiles,
    required this.heightTiles,
    this.isFullWidth = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: DashedBorder(
        color: theme.colorScheme.primary.withOpacity(0.3),
        strokeWidth: 1.5,
        gap: 5.0,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: isFullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Add Widgets",
                      style: TextStyle(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ),
      ),
    );
  }
}

//! =============================
//!    Widget Selection Sheet
//! =============================

class WidgetSelectionSheet extends StatelessWidget {
  const WidgetSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the list of currently active widget types
    final provider = Provider.of<HomeWidgetsProvider>(context);
    final activeTypes = provider.activeWidgets.map((w) => w.type).toSet();

    // 2. Define availability logic
    final bool canAddFolderWatchlist = !activeTypes.contains(
      HomeWidgetType.folderWatchlist,
    );
    final bool hasAvailableWidgets = canAddFolderWatchlist;

    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Add Widgets",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          if (!hasAvailableWidgets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You've added all available widgets!",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // FOLDER WATCHLIST PREVIEW TILE
                if (canAddFolderWatchlist)
                  _WidgetPreviewTile(
                    title: "Folders Watchlist",
                    description: "Monitor your folder budgets at a glance",
                    previewWidget: const _DummyFolderWatchlistWidget(),
                    onTap: () {
                      provider.addWidget(HomeWidgetType.folderWatchlist);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// --- 1. THE PREVIEW TILE CONTAINER ---
class _WidgetPreviewTile extends StatelessWidget {
  final String title;
  final String description;
  final Widget previewWidget;
  final VoidCallback onTap;

  const _WidgetPreviewTile({
    required this.title,
    required this.description,
    required this.previewWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The Preview Container
          Container(
            // height: 300, // Allow enough space for the widget
            width: double.infinity,
            padding: const EdgeInsets.all(24), // Padding around the widget
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(34),
            ),
            child: Column(
              // We constrain the width to simulate the 4x2 grid look
              children: [
                SizedBox(
                  height: 140, // Match Home Widget Height
                  child: previewWidget,
                ),
                const SizedBox(height: 16),
                // Title & Description
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. THE DUMMY WIDGET (Visual Copy of Real Widget) ---
class _DummyFolderWatchlistWidget extends StatelessWidget {
  const _DummyFolderWatchlistWidget();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Hardcoded Data for Preview
    final folders = [
      _DummyFolderData(
        name: 'Italy 2026',
        color: Colors.orange,
        spent: 32550,
        limit: 80000,
      ),
      _DummyFolderData(
        name: 'Office commute',
        color: Colors.blue,
        spent: 120,
        limit: 500,
        label: 'MONTHLY',
      ),
      _DummyFolderData(
        name: 'Home Rennovation',
        color: Colors.pink,
        spent: 290,
        limit: 300,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: folders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final folder = folders[index];
                final percent = (folder.spent / folder.limit).clamp(0.0, 1.0);
                final spentStr = folder.spent.toStringAsFixed(0);
                final limitStr = folder.limit.toStringAsFixed(0);

                return Column(
                  children: [
                    Row(
                      children: [
                        // Icon Circle
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: folder.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedFolder02,
                              size: 16,
                              color: folder.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    folder.name,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  if (folder.label != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        folder.label!,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),

                                  const Spacer(),
                                  Row(
                                    children: [
                                      Text(
                                        spentStr,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'momo',
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        " / $limitStr",
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).hintColor,
                                          fontFamily: 'momo',
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Bottom Row: Progress
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 4,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        color: percent > 0.95
                                            ? Colors.red
                                            : folder.color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(percent * 100).toInt()}%",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DummyFolderData {
  final String name;
  final Color color;
  final double spent;
  final double limit;
  final String? label;
  _DummyFolderData({
    required this.name,
    required this.color,
    required this.spent,
    required this.limit,
    this.label,
  });
}
