import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/widgets/auth_textfield.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart' as auth_provider;

class LoginScreen extends StatefulWidget {
  final VoidCallback onTap;
  const LoginScreen({super.key, required this.onTap});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ADDED: State variable for password visibility
  bool _isPasswordObscured = true;

  void _passwordReset() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return _PasswordResetDialogContent(initialEmail: emailController.text.trim());
      },
    ).then((message) {
      // emailController.dispose();
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  void _signIn() async {
    if (!mounted) return;
    final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: false);

    try {
      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Failed to sign in")),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The background will correctly use the theme's background color
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wallet, size: 80),
                const SizedBox(height: 40),
                const Text("Welcome back!", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email',
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  // CHANGED: Use the state variable here
                  obscureText: _isPasswordObscured,
                  // ADDED: The visibility toggle icon button
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _passwordReset,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<auth_provider.AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: auth.isLoading ? null : _signIn,
                        child: auth.isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Not a member?"),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        "Register now",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // CHANGED: Using theme-aware color
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add this new widget inside your login_screen.dart file

class _PasswordResetDialogContent extends StatefulWidget {
  final String initialEmail;

  const _PasswordResetDialogContent({required this.initialEmail});

  @override
  State<_PasswordResetDialogContent> createState() => _PasswordResetDialogContentState();
}

class _PasswordResetDialogContentState extends State<_PasswordResetDialogContent> {
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
    // Hide the keyboard
    FocusScope.of(context).unfocus();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      // Pop with a success message
      Navigator.of(context).pop('Password reset link sent! Check your email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Pop with an error message
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
          const Text("Enter your email and we'll send you a password reset link."),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Email"),
          ),
        ],
      ),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
        FilledButton(
          onPressed: _sendResetLink,
          child: const Text('Send Link'),
        ),
      ],
    );
  }
}