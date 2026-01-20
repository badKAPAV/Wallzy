import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/auth/screens/login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Ensure you have this package
import 'package:lottie/lottie.dart';

class AuthEmailScreen extends StatefulWidget {
  const AuthEmailScreen({super.key});

  @override
  State<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends State<AuthEmailScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State for the intro animation sequence
  bool _isLoading = true;

  // State for the email flow
  bool _emailSent = false;
  String? _sentEmailAddress;

  @override
  void initState() {
    super.initState();
    // Start the intro sequence
    _startLoadingSequence();
  }

  void _startLoadingSequence() async {
    // Wait for the intro animation (Total ~2.5 seconds)
    // 1. Fade in (0.8s) + Stay (1s) + Exit (0.5s)
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.sendMagicLink(email);
      setState(() {
        _emailSent = true;
        _sentEmailAddress = email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending link: $e')));
      }
    }
  }

  void _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign In failed: $e')));
      }
    }
  }

  Future<void> _openMailApp() async {
    if (Platform.isAndroid) {
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.APP_EMAIL',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      } catch (e) {
        try {
          const intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: 'com.google.android.gm',
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
        } catch (e) {
          final Uri emailLaunchUri = Uri(scheme: 'mailto');
          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
        }
      }
    } else {
      final Uri emailLaunchUri = Uri(scheme: 'mailto');
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Prevents keyboard from messing up the background vector
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. PERSISTENT BACKGROUND LAYER
          // We keep this outside the switcher so it doesn't jump during transitions
          Positioned(
            top: -230,
            right: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: SvgPicture.asset(
                'assets/vectors/landing_vector.svg',
                width: 500,
                height: 500,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ).animate().fadeIn(
            duration: 600.ms,
          ), // Smoothly fade in BG to hide red flash
          // 2. MAIN CONTENT STACK
          Stack(
            children: [
              // --- A. THE LOADING INTRO ---
              if (_isLoading)
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          [
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Lottie.asset(
                                    'assets/json/cubes_animation.json',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.contain,
                                    delegates: LottieDelegates(
                                      values: [
                                        ValueDelegate.strokeColor(
                                          const ['**'],
                                          value: theme
                                              .colorScheme
                                              .surfaceContainerHigh,
                                        ),
                                        ValueDelegate.color(const [
                                          '**',
                                        ], value: theme.colorScheme.primary),
                                      ],
                                    ),
                                  ),
                                ),

                                Text(
                                  'ledgr',
                                  style: TextStyle(
                                    fontFamily: 'momo',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Your money, mastered.',
                                  style: TextStyle(
                                    fontFamily: 'momo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ]
                              .animate(interval: 100.ms)
                              .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                              .moveY(
                                begin: 30,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              )
                              // STAY PHASE
                              .then(delay: 1000.ms)
                              // EXIT PHASE
                              .moveY(
                                end: -30,
                                duration: 500.ms,
                                curve: Curves.easeInOut,
                              )
                              .fadeOut(duration: 400.ms),
                    ),
                  ),
                ),

              // --- B. THE ACTUAL CONTENT (FORM / SUCCESS) ---
              if (!_isLoading)
                Positioned.fill(
                  child: SafeArea(
                    // AnimatedSwitcher handles the smooth morph between
                    // "Enter Email" and "Check Inbox"
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: _emailSent
                          ? _buildSuccessView(context)
                          : _buildFormView(context),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- VIEW 1: THE FORM ---
  Widget _buildFormView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);

    return Padding(
      key: const ValueKey('AuthForm'), // Important for AnimatedSwitcher
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Headings
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                "assets/vectors/ledgr.svg",
                width: 100,
                height: 100,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            Text(
              'Welcome to\nledgr',
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 44,
                height: 1.1,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your email address to get started',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 30),

            // Email Input
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'johndoe@example.com',
                labelText: 'Email Address',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedMail01),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Continue Button
            FilledButton(
              onPressed: authProvider.isLoading ? null : _handleContinue,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: authProvider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Verification link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outlineVariant)),
              ],
            ),
            const SizedBox(height: 24),

            // Google Sign In
            OutlinedButton.icon(
              onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedGoogle,
                color: colorScheme.onSurface,
              ),
              label: Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Manual Login Option
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: Text(
                "Sign in with password",
                style: TextStyle(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'By continuing, you agree to our Terms of Service & Privacy Policy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- VIEW 2: SUCCESS STATE ---
  Widget _buildSuccessView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      key: const ValueKey('SuccessView'), // Important for AnimatedSwitcher
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container
            GestureDetector(
              onTap: _openMailApp,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMail01,
                  color: colorScheme.primary,
                  size: 56,
                ),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 48),

            FilledButton.tonal(
              onPressed: _openMailApp,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Check your inbox',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 12),

            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'We sent a magic sign-in link to\n'),
                  TextSpan(
                    text: _sentEmailAddress,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text: '.\n\nDon\'t forget to check your spam folder!',
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 48),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  _emailSent = false;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Use a different email',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
