import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';

class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              Text('Account Suspended', 
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 8),
              Text('Your account has been suspended for violating community guidelines.', 
                textAlign: TextAlign.center, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(), 
                child: Text('Sign Out', style: TextStyle(color: colors.secondary))
              ),
            ],
          ),
        ),
      ),
    );
  }
}
