import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon; // ADDED: To accept a widget like an IconButton

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon, // ADDED: New property in constructor
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        // CHANGED: Using the theme's outline color for a subtle border
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(128)),
        ),
        // CHANGED: Using primary color for the focused border
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        fillColor: colorScheme.surface,
        filled: true,
        hintText: hintText,
        // CHANGED: Using a theme-aware color for the hint text
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        suffixIcon: suffixIcon, // ADDED: Displays the passed-in icon
      ),
    );
  }
}
