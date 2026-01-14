import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart'
    as auth_provider;
import 'package:wallzy/features/auth/widgets/auth_widgets.dart';
import 'package:wallzy/core/helpers/auth_error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;

  void _passwordReset() {
    // [Keep existing logic, just styling the dialog later if needed]
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    showDialog<String?>(
      context: context,
      builder: (dialogContext) => _PasswordResetDialogContent(
        initialEmail: emailController.text.trim(),
      ),
    ).then((message) {
      if (message != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  void _signIn() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter your email address"),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter your password"),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<auth_provider.AuthProvider>(
      context,
      listen: false,
    );
    try {
      await authProvider.signIn(email, password);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthErrorHandler.getUserFriendlyMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
      ),
      body: Stack(
        children: [
          // 1. Animated Background
          const AuthBackground(),

          // 2. Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Logo / Icon
                // AuthHeaderIcon(icon: Icons.waving_hand_outlined),
                // const SizedBox(height: 32),

                // // Welcome Text
                // Text(
                //   "Look who's back!",
                //   style: theme.textTheme.headlineMedium?.copyWith(
                //     fontWeight: FontWeight.bold,
                //     color: theme.colorScheme.onSurface,
                //   ),
                // ).animate().fadeIn().slideY(begin: 0.3, end: 0),
                const SizedBox(height: 120),
                Text(
                  "Login using your credentials",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'momo',
                    fontSize: 36,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),

                const SizedBox(height: 60),

                // Form Container
                Column(
                  children: [
                    ModernTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    ModernTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _isPasswordObscured,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordObscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordObscured = !_isPasswordObscured,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _passwordReset,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.secondary,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<auth_provider.AuthProvider>(
                      builder: (context, auth, _) {
                        return SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: auth.isLoading ? null : _signIn,
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                // Footer
                // Signup removed as per requirements (Signup only via Magic Link)
                /*
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "New to Ledgr? ",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
                */
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordResetDialogContent extends StatefulWidget {
  final String initialEmail;
  const _PasswordResetDialogContent({required this.initialEmail});
  @override
  State<_PasswordResetDialogContent> createState() =>
      _PasswordResetDialogContentState();
}

class _PasswordResetDialogContentState
    extends State<_PasswordResetDialogContent> {
  late final TextEditingController _emailController;
  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop('Password reset link sent! Check your email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(e.message ?? 'An error occurred');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter your email and we'll send you a password reset link.",
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _emailController,
            hintText: "Email",
            icon: Icons.email_outlined,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          onPressed: _sendResetLink,
          child: const Text('Send Link'),
        ),
      ],
    );
  }
}
