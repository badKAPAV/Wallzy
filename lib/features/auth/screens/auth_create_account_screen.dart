import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';

class AuthCreateAccountScreen extends StatefulWidget {
  const AuthCreateAccountScreen({super.key});

  @override
  State<AuthCreateAccountScreen> createState() =>
      _AuthCreateAccountScreenState();
}

class _AuthCreateAccountScreenState extends State<AuthCreateAccountScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  DateTime? _selectedDOB;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null && user.name.isNotEmpty) {
      _nameController.text = user.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDOB ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              headerForegroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  void _completeSetup() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.completeRegistration(
        name: _nameController.text.trim(),
        dob: _selectedDOB,
        imageFile: _selectedImage,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handlePopAttempt(bool didPop) {
    if (didPop) return;

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Please complete your profile to continue",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handlePopAttempt(didPop),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            Positioned(
              top: -150,
              right: -100,
              left: -100,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: SvgPicture.asset(
                  'assets/vectors/create_account_gradient_vector.svg',
                  width: 500,
                  height: 500,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary.withAlpha(100),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      Text(
                        "Let's get to know more about you",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'momo',
                          fontSize: 36,
                        ),
                        textAlign: TextAlign.start,
                      ),

                      const SizedBox(height: 40),

                      // 2. Profile Avatar Section
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring (optional, creates depth)
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // The Avatar
                              Hero(
                                tag: 'profile_pic',
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  backgroundImage: _selectedImage != null
                                      ? FileImage(_selectedImage!)
                                      : (currentUser?.photoURL != null
                                            ? NetworkImage(
                                                    currentUser!.photoURL!,
                                                  )
                                                  as ImageProvider
                                            : null),
                                  child:
                                      (_selectedImage == null &&
                                          currentUser?.photoURL == null)
                                      ? HugeIcon(
                                          icon: HugeIcons.strokeRoundedUser,
                                          size: 48,
                                          color: colorScheme.primary,
                                        )
                                      : null,
                                ),
                              ),
                              // Edit Badge
                              Positioned(
                                bottom: 0,
                                right: 4,
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.surface,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 3. Input Fields Card
                      Column(
                        children: [
                          // Name Input
                          TextFormField(
                            controller: _nameController,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'e.g. John Doe',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedUser,
                                  size: 22,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLow,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Please enter your name'
                                : null,
                          ),

                          const SizedBox(height: 16),

                          // DOB Picker (Looks like a field)
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 4),
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedCalendar03,
                                    size: 22,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_selectedDOB != null)
                                          Text(
                                            "Date of Birth",
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme.hintColor,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        Text(
                                          _selectedDOB == null
                                              ? 'Date of Birth (Optional)'
                                              : DateFormat.yMMMMd().format(
                                                  _selectedDOB!,
                                                ),
                                          style: _selectedDOB == null
                                              ? theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      color: theme.hintColor,
                                                    )
                                              : theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // 4. Main Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : _completeSetup,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: authProvider.isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.onSurface,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      "Get Started",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                      ),

                      // Bottom spacer for larger screens
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.05,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
