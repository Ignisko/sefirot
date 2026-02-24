import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'presentation/auth/login_screen.dart';
import 'presentation/home/home_screen.dart';
import 'core/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
  } catch (e) {
    debugPrint("Firebase initialization failed/skipped: $e");
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
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Sefirot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE30022), // WYD Seoul Red
          primary: const Color(0xFFE30022),
          secondary: const Color(0xFF003478), // WYD Seoul Blue
          tertiary: const Color(0xFFF1A000), // WYD Seoul Yellow
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          body: Center(child: Text("Auth Error: $error")),
        ),
      ),
    );
  }
}
