import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/auth/screens/auth_create_account_screen.dart';
import 'package:wallzy/features/auth/screens/auth_email_screen.dart';
import 'package:wallzy/features/dashboard/screens/home_screen.dart';
import 'package:wallzy/features/dashboard/widgets/loading_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 1. Determine which screen to show & Assign unique ValueKeys
        // Keys are CRITICAL for AnimatedSwitcher to identify changes
        Widget child;
        Key currentKey;

        if (authProvider.isAuthLoading) {
          currentKey = const ValueKey('loading_screen');
          child = LoadingScreen(key: currentKey);
        } else if (authProvider.isLoggedIn) {
          if (authProvider.isNewUser) {
            currentKey = const ValueKey('create_account');
            child = AuthCreateAccountScreen(key: currentKey);
          } else {
            currentKey = const ValueKey('home_screen');
            child = HomeScreen(key: currentKey);
          }
        } else {
          currentKey = const ValueKey('auth_email');
          child = AuthEmailScreen(key: currentKey);
        }

        // 2. Animate the transition
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 1000),
          switchInCurve: Curves.easeInOutCubicEmphasized,
          switchOutCurve: Curves.easeInOutCubicEmphasized,
          layoutBuilder: (currentChild, previousChildren) {
            // CRITICAL: Ensure Loading Screen stays ON TOP during transitions.
            // If LoadingScreen is entering (currentChild), it goes on top.
            // If LoadingScreen is leaving (in previousChildren), it goes on top.
            final isCurrentLoading =
                currentChild?.key == const ValueKey('loading_screen');

            return Stack(
              alignment: Alignment.center,
              children: isCurrentLoading
                  ? [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ] // Loading entering -> Top
                  : [
                      if (currentChild != null) currentChild,
                      ...previousChildren,
                    ], // Loading leaving -> Top
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isLoadingScreen =
                child.key == const ValueKey('loading_screen');

            if (isLoadingScreen) {
              // LOADING SCREEN TRANSITION (The Curtain)
              // Enter: Slide DOWN from top (-1 -> 0)
              // Exit: Slide UP to top (0 -> -1)
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1), // Start completely off-screen top
                  end: Offset.zero,
                ).animate(animation),
                child: child,
                // No Fade needed for the curtain itself, it's opaque.
                // But if user wants "fade out", we can add a slight fade at the very end.
              );
            }

            // CONTENT SCREEN TRANSITION (The Stage)
            // Just faint fade to smooth the harshness if curtain lifts too fast
            return FadeTransition(opacity: animation, child: child);
          },
          child: child,
        );
      },
    );
  }
}
