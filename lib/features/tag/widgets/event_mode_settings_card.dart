import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';

class EventModeSettingsCard extends StatefulWidget {
  final Tag tag;

  const EventModeSettingsCard({super.key, required this.tag});

  @override
  State<EventModeSettingsCard> createState() => _EventModeSettingsCardState();
}

class _EventModeSettingsCardState extends State<EventModeSettingsCard> {
  Future<void> _pickDateRange(
    BuildContext context,
    MetaProvider metaProvider,
    Color activeColor,
  ) async {
    final theme = Theme.of(context);
    final initialStart = widget.tag.eventStartDate ?? DateTime.now();
    final initialEnd =
        widget.tag.eventEndDate ?? initialStart.add(const Duration(days: 7));

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
            child: Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: activeColor,
                  onPrimary: Colors.white,
                  onSurface: theme.colorScheme.onSurface,
                ),
                datePickerTheme: DatePickerThemeData(
                  headerBackgroundColor: activeColor,
                  headerForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DateRangePickerDialog(
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: DateTimeRange(
                    start: initialStart,
                    end: initialEnd,
                  ),
                  saveText: "APPLY",
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final updatedTag = Tag(
        id: widget.tag.id,
        name: widget.tag.name,
        color: widget.tag.color,
        createdAt: widget.tag.createdAt,
        tagBudgetFrequency: widget.tag.tagBudgetFrequency,
        tagBudget: widget.tag.tagBudget,
        eventStartDate: picked.start,
        eventEndDate: picked.end,
      );
      await metaProvider.updateTag(updatedTag);
    }
  }

  Color lighten(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return hslLight.toColor().withAlpha(color.alpha);
  }

  @override
  Widget build(BuildContext context) {
    final metaProvider = Provider.of<MetaProvider>(context);
    final bool isEventMode = metaProvider.isEventModeEnabled(widget.tag.id);
    final bool isAutoAdd = metaProvider.isAutoAddEnabled(widget.tag.id);
    final theme = Theme.of(context);

    // Check brightness to determine toggle color logic
    final isDarkMode = theme.brightness == Brightness.dark;

    // --- COLOR LOGIC ---
    final Color activeColor = widget.tag.color != null
        ? Color(widget.tag.color!)
        : theme.colorScheme.primary;

    // 1. Calculate SOLID colors to prevent alpha-flashing during interpolation.
    final Color surfaceColor = theme.colorScheme.surface;

    // The "On" state: Surface + 8% Tint of active color
    final Color activeBackground = Color.alphaBlend(
      activeColor.withValues(alpha: 0.08),
      surfaceColor,
    );

    // The "Off" state: Pure Surface
    final Color backgroundColor = isEventMode ? activeBackground : surfaceColor;

    // 2. Border Color Logic
    final Color borderColor = isEventMode
        ? activeColor.withValues(alpha: 0.5)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isEventMode ? 1.5 : 1),
        boxShadow: isEventMode
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header Row ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEventMode
                        ? activeColor
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    color: isEventMode
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                    size: 22,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Event Mode",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, -0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          key: ValueKey(isEventMode),
                          isEventMode
                              ? isAutoAdd
                                    ? "Transactions are auto added 🎉"
                                    : "Enable auto add to track"
                              : "Make the most out of your folders",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isEventMode
                                ? activeColor
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isEventMode
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch.adaptive(
                    value: isEventMode,
                    // Use lighten only in dark mode, otherwise use raw activeColor
                    activeThumbColor: isDarkMode
                        ? lighten(activeColor)
                        : activeColor,
                    activeTrackColor: activeColor.withValues(alpha: 0.4),
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      await metaProvider.setEventMode(widget.tag.id, val);
                      if (val && widget.tag.eventStartDate == null) {
                        final now = DateTime.now();
                        final updatedTag = Tag(
                          id: widget.tag.id,
                          name: widget.tag.name,
                          color: widget.tag.color,
                          createdAt: widget.tag.createdAt,
                          tagBudgetFrequency: widget.tag.tagBudgetFrequency,
                          tagBudget: widget.tag.tagBudget,
                          eventStartDate: now,
                          eventEndDate: now.add(const Duration(days: 7)),
                        );
                        await metaProvider.updateTag(updatedTag);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- Expandable Body ---
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            alignment: Alignment.topCenter,
            child: isEventMode
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Divider(
                          height: 1,
                          color: activeColor.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),

                        // Date Picker Tile
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _pickDateRange(
                                context,
                                metaProvider,
                                activeColor,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  surfaceColor,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: activeColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 20,
                                    color: activeColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Active Duration",
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.tag.eventStartDate != null &&
                                                  widget.tag.eventEndDate !=
                                                      null
                                              ? "${DateFormat.MMMd().format(widget.tag.eventStartDate!)} - ${DateFormat.MMMd().format(widget.tag.eventEndDate!)}"
                                              : "Select Dates",
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Auto Add Toggle Tile
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAutoAdd
                                ? Color.alphaBlend(
                                    activeColor.withValues(alpha: 0.15),
                                    surfaceColor,
                                  )
                                : Color.alphaBlend(
                                    theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    surfaceColor,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAutoAdd
                                  ? activeColor.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant.withValues(
                                      alpha: 0.4,
                                    ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedSparkles,
                                  color: isAutoAdd
                                      ? activeColor
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Auto-Add Transactions",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      "Txns added to folder when in range",
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isAutoAdd,
                                activeThumbColor: isDarkMode
                                    ? lighten(activeColor)
                                    : activeColor,
                                activeTrackColor: activeColor.withValues(
                                  alpha: 0.4,
                                ),
                                onChanged: (val) async {
                                  HapticFeedback.lightImpact();
                                  if (val) {
                                    await metaProvider.setAutoAddTag(
                                      widget.tag.id,
                                      true,
                                    );
                                  } else {
                                    if (metaProvider.isAutoAddEnabled(
                                      widget.tag.id,
                                    )) {
                                      await metaProvider.setAutoAddTag(
                                        widget.tag.id,
                                        false,
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
