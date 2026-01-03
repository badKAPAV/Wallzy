import 'package:flutter/material.dart';

class RollingBalance extends StatefulWidget {
  final bool isVisible;
  final String symbol;
  final double amount;
  final TextStyle? style;

  const RollingBalance({
    super.key,
    required this.isVisible,
    required this.symbol,
    required this.amount,
    this.style,
  });

  @override
  State<RollingBalance> createState() => _RollingBalanceState();
}

class _RollingBalanceState extends State<RollingBalance> {
  @override
  Widget build(BuildContext context) {
    final valueString = widget.amount.toStringAsFixed(2);
    final hiddenString =
        "•" * (valueString.length > 6 ? 6 : valueString.length);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(widget.symbol, style: widget.style),
        const SizedBox(width: 4),

        // This handles the width expansion/contraction smoothly
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            // This ensures the outgoing and incoming widgets are aligned correctly
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            // A subtle fade + scale makes it look like it's morphing
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation, // Reveals width smoothly
                  axis: Axis.horizontal,
                  axisAlignment: -1.0, // Start from left
                  child: child,
                ),
              );
            },
            // THE CONTENT SWITCH
            child: widget.isVisible
                ? Row(
                    key: const ValueKey('visible_amount'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: valueString.split('').map((char) {
                      if (RegExp(r'[0-9]').hasMatch(char)) {
                        return _RollingDigit(
                          targetValue: int.parse(char),
                          style: widget.style,
                        );
                      } else {
                        return Text(char, style: widget.style);
                      }
                    }).toList(),
                  )
                : Text(
                    hiddenString,
                    key: const ValueKey('hidden_dots'),
                    style: widget.style?.copyWith(letterSpacing: 2),
                  ),
          ),
        ),
      ],
    );
  }
}

// Keep this exactly as it was in the fixed version
class _RollingDigit extends StatelessWidget {
  final int targetValue;
  final TextStyle? style;

  const _RollingDigit({required this.targetValue, this.style});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text("8", style: style)),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final digitHeight = constraints.maxHeight;
              return ClipRect(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: targetValue.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -value * digitHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(10, (index) {
                          return SizedBox(
                            height: digitHeight,
                            child: Text(index.toString(), style: style),
                          );
                        }),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
