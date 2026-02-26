import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    // Show a rudimentary error screen if Firebase fails entirely.
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app core.\nPlease restart the app.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    const ProviderScope(
      child: SefirotApp(),
    ),
  );
}

class SefirotApp extends ConsumerWidget {
  const SefirotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Pelegrin',
      routerConfig: router,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      themeMode: ref.watch(themeProvider),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCD2E3A), // WYD Seoul Red
          primary: const Color(0xFFCD2E3A),
          secondary: const Color(0xFF0047A0), // WYD Seoul Blue
          tertiary: const Color(0xFFFFD100), // WYD Seoul Yellow
          surface: const Color(0xFFFDFBF7), // Light Cream background
          onSurface: const Color(0xFF0A0A0A), // Dark text
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        cardColor: const Color(0xFFFFFFFF),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCD2E3A),
          primary: const Color(0xFFCD2E3A),
          secondary: const Color(0xFF0047A0), 
          tertiary: const Color(0xFFFFD100),
          surface: const Color(0xFF121212), // Dark background
          onSurface: const Color(0xFFF0F0F0), // Light text
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
    );
  }
}
