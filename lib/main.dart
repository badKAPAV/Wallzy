import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/screens/auth_gate.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set default animation durations
  Animate.defaultDuration = 300.ms;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MetaProvider>(
          create: (context) =>
              MetaProvider(authProvider: context.read<AuthProvider>()),
          update: (_, auth, previous) => MetaProvider(authProvider: auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (context) =>
              TransactionProvider(authProvider: context.read<AuthProvider>()),
          update: (_, auth, previous) => TransactionProvider(authProvider: auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallzy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Using our new expressive theme
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Enforce dark mode
      home: const AuthGate(),
    );
  }
}