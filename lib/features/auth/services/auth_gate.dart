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
        // 1. Check if auth state is still loading
        if (authProvider.isAuthLoading) {
          return const LoadingScreen();
        }

        // 2. Check if user is logged in
        if (authProvider.isLoggedIn) {
          // 3. User logged in -> Check if new user (needs registration)
          if (authProvider.isNewUser) {
            return const AuthCreateAccountScreen();
          }
          // 4. Existing user -> Home
          return const HomeScreen();
        }

        // 5. Not logged in -> Login Screen
        return const AuthEmailScreen();
      },
    );
  }
}
