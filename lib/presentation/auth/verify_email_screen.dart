import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = true;
  bool isResending = false;
  Timer? timer;
  Timer? _resendTimer; // Cancellable replacement for Future.delayed

  String get _userEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'your email address';

  @override
  void initState() {
    super.initState();
    isEmailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _resendTimer?.cancel(); // Cancel the 30-second cooldown if screen is disposed
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final verified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (verified && mounted) {
      timer?.cancel();
      setState(() => isEmailVerified = true);
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (!canResendEmail) return;
    setState(() {
      isResending = true;
      canResendEmail = false;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: Color(0xFF0047A0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isResending = false);
      // Allow resend after 30 seconds — use a cancellable Timer instead of
      // Future.delayed so it doesn't fire setState after the widget is disposed.
      _resendTimer?.cancel();
      _resendTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => canResendEmail = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEmailVerified) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    const primaryBlue = Color(0xFF0047A0);
    const primaryRed = Color(0xFFCD2E3A);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 52,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'Check your email',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'We sent a verification link to:',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click the link in the email to activate your account.\nThis page will update automatically.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Primary CTA
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _checkEmailVerified,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text(
                      'I have verified — continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: canResendEmail && !isResending
                        ? _sendVerificationEmail
                        : null,
                    icon: isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.email_outlined),
                    label: Text(
                      canResendEmail ? 'Resend verification email' : 'Email sent — wait 30s',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: const BorderSide(color: primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledForegroundColor: Colors.black38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign out
                TextButton.icon(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout, size: 18, color: primaryRed),
                  label: const Text(
                    'Cancel and sign out',
                    style: TextStyle(color: primaryRed, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
