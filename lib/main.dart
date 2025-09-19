import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/auth/screens/auth_gate.dart';
// Note: The home screen import was unused, so it can be removed.
// import 'package:wallzy/features/dashboard/screens/home_screen.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    // Wrap the entire app in MultiProvider at the top level.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Use ChangeNotifierProxyProvider to pass the AuthProvider instance
        // to dependent providers without losing their state.
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (context) => TransactionProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (_, auth, previous) => previous!..updateAuthProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MetaProvider>(
          create: (context) => MetaProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (_, auth, previous) => previous!..updateAuthProvider(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //? default color schemes as a fallback
  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFA40000),
  );

  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFA40000),
    brightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    // Use a single DynamicColorBuilder.
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;
        CorePalette? corePalette;

        // //* ================================
        // //* TEST CODE

        // const seedColor =
        //     Color(0xFFA40000);

        //     corePalette = CorePalette.of(seedColor.value);

        // lightColorScheme = ColorScheme.fromSeed(seedColor: seedColor);
        // darkColorScheme = ColorScheme.fromSeed(
        //   seedColor: seedColor,
        //   brightness: Brightness.dark,
        // );

        // //* ================================

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
          corePalette = CorePalette.of(lightColorScheme.primary.value);
        } else {
          lightColorScheme = _defaultLightColorScheme;
          darkColorScheme = _defaultDarkColorScheme;
          corePalette = CorePalette.of(lightColorScheme.primary.value);
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Wallzy',
          theme: AppTheme.buildTheme(lightColorScheme, corePalette: corePalette),
          darkTheme: AppTheme.buildTheme(darkColorScheme, corePalette: corePalette),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}
