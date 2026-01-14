import 'package:flutter/material.dart';

class FooterGraphic extends StatelessWidget {
  const FooterGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100),
          Text(
            "Your money, \nmastered.",
            style: TextStyle(
              color: colorScheme.primary.withValues(alpha: 0.4),
              fontFamily: 'momo',
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Made with 🫰🏼 by Kapav',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
