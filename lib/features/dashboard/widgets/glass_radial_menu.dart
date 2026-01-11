import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/dashboard/models/radial_menu_item_model.dart';

class GlassRadialMenu extends StatefulWidget {
  final List<RadialMenuItem> menuItems;
  final VoidCallback onFabTap;
  final bool isFabExtended;

  const GlassRadialMenu({
    super.key,
    required this.menuItems,
    required this.onFabTap,
    required this.isFabExtended,
  });

  @override
  State<GlassRadialMenu> createState() => _GlassRadialMenuState();
}

class _GlassRadialMenuState extends State<GlassRadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Rotation Logic for the "Dial" effect
  double _currentRotation = 0.0;
  final double _baseRotation =
      -math.pi / 2; // Start at -90 degrees (Straight up)

  bool get _isOpen => _overlayEntry != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
      HapticFeedback.mediumImpact();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    // Reset rotation when opening
    setState(() => _currentRotation = 0.0);
  }

  Future<void> _closeMenu() async {
    if (!_isOpen) return;
    await _controller.reverse();
    _removeOverlay();
    if (mounted) {
      setState(() {}); // Rebuild to show the original FAB text if needed
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // --- The Overlay Logic ---
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 1. Blur & Dark Scrim
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                // Drag Logic for "Dial" feel
                onPanUpdate: (details) {
                  double delta = details.delta.dx * 0.01;
                  // We use a stateful builder or similar mechanism if we want the overlay to rebuild
                  // based on internal state changes without calling setState on the parent.
                  // However, since OverlayEntry builder runs in the context, we can trigger
                  // the overlay to markNeedsBuild via a local state management or simple variable capture.
                  // For simplicity in this structure, we modify the variable and rebuild the overlay.
                  _currentRotation += delta;
                  _currentRotation = _currentRotation.clamp(-0.5, 0.5);
                  _overlayEntry?.markNeedsBuild();
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    return BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 5 * value,
                        sigmaY: 5 * value,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(0.4 * value),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. The Radial Menu Items
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                // Offset to center the menu around the FAB
                offset: const Offset(-150, -152),
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final radius = 110.0 * _expandAnimation.value;

                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < widget.menuItems.length; i++)
                            _buildRadialItem(
                              index: i,
                              total: widget.menuItems.length,
                              radius: radius,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. The "Anchor" FAB (Overlay Copy)
            // We render a copy of the FAB here so it sits ON TOP of the dark overlay
            Positioned(
              width: 60, // Force collapsed width
              height: 56,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset.zero,
                child: Material(
                  color: Colors.transparent,
                  child: _buildFabContent(isOverlay: true),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRadialItem({
    required int index,
    required int total,
    required double radius,
  }) {
    // Arc Logic: Distribute items over 180 degrees (Pi) centered at top
    final double spread = total > 1 ? math.pi * 0.8 : 0;
    final double startAngle = _baseRotation - (spread / 2);
    final double step = total > 1 ? spread / (total - 1) : 0;
    final double itemBaseAngle = startAngle + (step * index);

    // Add the user's drag rotation
    final double finalAngle = itemBaseAngle + _currentRotation;

    final double x = radius * math.cos(finalAngle);
    final double y = radius * math.sin(finalAngle);

    // Staggered Entrance Animation
    final double intervalStart = 0.0 + (index / total) * 0.5;
    final double intervalEnd = 0.5 + (index / total) * 0.5;

    final Animation<double> itemScale = CurvedAnimation(
      parent: _controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutBack),
    );

    return Transform.translate(
      offset: Offset(x, y),
      child: ScaleTransition(
        scale: itemScale,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            _closeMenu();
            widget.menuItems[index].onTap();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Glass Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: _buildIcon(widget.menuItems[index].icon),
                ),
              ),
              const SizedBox(height: 6),
              // Label with Shadow for readability on dark overlay
              Material(
                color: Colors.transparent,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.menuItems[index].label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(dynamic iconData) {
    if (iconData is IconData) {
      return Icon(
        iconData,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      );
    } else if (iconData is Widget) {
      return iconData;
    } else {
      // Assuming HugeIcon support is needed
      return HugeIcon(
        icon: iconData,
        color: Theme.of(context).colorScheme.primary,
        strokeWidth: 2,
        size: 24,
      );
    }
  }

  // Reuse the FAB design for both the main widget and the overlay copy
  Widget _buildFabContent({bool isOverlay = false}) {
    // If we are in the Overlay, force collapse.
    // If in main tree, respect isFabExtended UNLESS menu is open (then collapse)
    final bool effectiveExtended = isOverlay
        ? false
        : (widget.isFabExtended && !_isOpen);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: effectiveExtended ? 130 : 60,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // If in overlay, tap closes. If in main, tap opens normal action or Long press opens menu
          onTap: isOverlay ? _closeMenu : widget.onFabTap,
          onLongPress: isOverlay ? null : _toggleMenu,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _rotateAnimation,
                  child: Icon(
                    Icons.add_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                if (effectiveExtended) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Create",
                      style: TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      // When menu is open, we can either hide this FAB or leave it.
      // Leaving it prevents layout jumps. The Overlay FAB covers it perfectly.
      child: _buildFabContent(isOverlay: false),
    );
  }
}
