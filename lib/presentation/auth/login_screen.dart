import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_controller.dart';
import '../../core/providers/auth_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────







// ── Login Screen ──────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // null = hero landing; true = sign-up card; false = log-in card
  bool? _mode;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _openSignUp()  => setState(() => _mode = true);
  void _openLogIn()   => setState(() => _mode = false);
  void _toggleMode()  => setState(() => _mode = !(_mode ?? false));
  void _closeForm()   => setState(() => _mode = null);

  void _submit() {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _snack('Please enter email and password');
      return;
    }
    if (_mode == true) {
      final name = _firstNameCtrl.text.trim();
      ref
          .read(authControllerProvider.notifier)
          .signUpWithEmail(email, pass, displayName: name);
    } else {
      ref.read(authControllerProvider.notifier).signInWithEmail(email, pass);
    }
  }

  void _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Please enter your email address first to reset password.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      _snack('Password reset email sent to $email!');
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _google() =>
      ref.read(authControllerProvider.notifier).signInWithGoogle();

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, s) {
      s.whenOrNull(error: (e, _) => _snack(e.toString()));
    });

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      body: Stack(
        children: [
          // ── 1. Hero — always rendered, fades when form opens ──────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _mode == null ? 1.0 : 0.0,
            // Keep it in tree for smooth fade; IgnorePointer while hidden
            child: IgnorePointer(
              ignoring: _mode != null,
              child: _HeroPage(
                onSignUp: _openSignUp,
                onLogIn: _openLogIn,
              ),
            ),
          ),

          // ── 2. Dim overlay + centered auth card ──────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _mode != null ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: _mode == null,
              child: Container(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: _mode != null
                    ? _AuthCard(
                        isSignUp: _mode!,
                        loading: loading,
                        firstNameCtrl: _firstNameCtrl,
                        lastNameCtrl: _lastNameCtrl,
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        onToggle: _toggleMode,
                        onSubmit: _submit,
                        onGoogle: _google,
                        onClose: _closeForm,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero page (full screen, always behind) ────────────────────────────────────
class _HeroPage extends StatelessWidget {
  final VoidCallback onSignUp, onLogIn;
  const _HeroPage({required this.onSignUp, required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 28, vertical: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoMark(size: isWide ? 42 : 32),
          const Spacer(),
          Text(
            isWide ? 'Pilgrim\nMatching.' : 'Pilgrim Matching.',
            style: GoogleFonts.outfit(
                fontSize: isWide ? 42 : 32,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 16, color: Colors.black54, height: 1.6),
                children: [
                  const TextSpan(text: 'Where pilgrims heading to '),
                  TextSpan(
                    text: 'Seoul 2027',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text:
                          ' connect, find travel companions, and share the journey.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          Row(children: [
            _HeroBtn(
                label: 'Sign up', filled: true, onTap: onSignUp),
            const SizedBox(width: 12),
            _HeroBtn(
                label: 'Log in', filled: false, onTap: onLogIn),
          ]),
          const SizedBox(height: 28),
          const Spacer(),
          const _FishCross(),
        ],
      ),
    );
  }
}

// ── Auth card (centered on dimmed bg) ─────────────────────────────────────────
class _AuthCard extends StatelessWidget {
  final bool isSignUp, loading;
  final TextEditingController firstNameCtrl, lastNameCtrl, emailCtrl, passCtrl;
  final VoidCallback onToggle, onSubmit, onGoogle, onClose;

  const _AuthCard({
    required this.isSignUp,
    required this.loading,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.onToggle,
    required this.onSubmit,
    required this.onGoogle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Card top: logo + close ────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(children: [
                      _LogoMark(),
                      const Spacer(),
                      // Close ×
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('×',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black45,
                                    height: 1)),
                          ),
                        ),
                      ),
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            key: ValueKey(isSignUp),
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSignUp
                                    ? 'Create account'
                                    : 'Welcome back',
                                style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSignUp
                                    ? 'Join pilgrims from 20+ countries.'
                                    : 'Sign in to continue your journey.',
                                style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Google button — fixed Row layout (no overlap)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: loading ? null : onGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(26)),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                // White circle with G
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text('G',
                                      style: TextStyle(
                                          color: Color(0xFF4285F4),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isSignUp ? 'Sign up with Google' : 'Continue with Google',
                                    style: TextStyle(
                                        color: Theme.of(context).cardColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 10),
                            child: Text('or',
                                style: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 12)),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 12),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: isSignUp
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _Field(
                                    ctrl: firstNameCtrl,
                                    label: 'Name',
                                  ),
                                )
                              : const SizedBox(width: double.infinity, height: 0),
                        ),

                        _Field(
                            ctrl: emailCtrl,
                            label: 'Email address'),
                        const SizedBox(height: 8),
                        _Field(
                            ctrl: passCtrl,
                            label: 'Password',
                            obscure: true),
                        if (!isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Will be passed from parent
                                final state = context.findAncestorStateOfType<_LoginScreenState>();
                                state?._forgotPassword();
                              },
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  minimumSize: Size.zero),
                              child: Text('Forgot password?', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: loading ? null : onSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: loading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Theme.of(context).cardColor,
                                        strokeWidth: 2))
                                : AnimatedSwitcher(
                                    duration: const Duration(
                                        milliseconds: 160),
                                    child: Text(
                                      isSignUp
                                          ? 'Sign up'
                                          : 'Log in',
                                      key: ValueKey(isSignUp),
                                      style: TextStyle(
                                          color: Theme.of(context).cardColor,
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ),

                        // Toggle
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: onToggle,
                            child: AnimatedSwitcher(
                              duration:
                                  const Duration(milliseconds: 160),
                              child: RichText(
                                key: ValueKey(isSignUp),
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black45),
                                  children: isSignUp
                                      ? [
                                          const TextSpan(
                                              text:
                                                  'Already have an account?  '),
                                          TextSpan(
                                              text: 'Log in',
                                              style: TextStyle(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          const WidgetSpan(child: SizedBox(width: 4)),
                                          WidgetSpan(child: Icon(Icons.login_rounded, size: 14, color: Theme.of(context).colorScheme.secondary)),
                                        ]
                                      : [
                                          const TextSpan(
                                              text:
                                                  "Don't have an account?  "),
                                          TextSpan(
                                              text: 'Sign up',
                                              style: TextStyle(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          const WidgetSpan(child: SizedBox(width: 4)),
                                          WidgetSpan(child: Icon(Icons.person_add_rounded, size: 14, color: Theme.of(context).colorScheme.secondary)),
                                        ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating-label underline field ────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  const _Field(
      {required this.ctrl, required this.label, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Colors.black45, fontSize: 14),
        floatingLabelStyle: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w600),
        filled: false,
        contentPadding:
            const EdgeInsets.only(bottom: 8, top: 20),
        border: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black26)),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black26)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2)),
      ),
    );
  }
}

// ── Logo mark ─────────────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 17});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: size * 0.3,
          height: size * 1.2,
          color: Theme.of(context).colorScheme.primary,
          margin: const EdgeInsets.only(right: 4)),
      Container(
          width: size * 0.3,
          height: size * 1.2,
          color: Theme.of(context).colorScheme.secondary,
          margin: const EdgeInsets.only(right: 8)),
      Text('Pelegrin',
          style: GoogleFonts.outfit(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

// ── Hero CTA button ───────────────────────────────────────────────────────────
class _HeroBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _HeroBtn(
      {required this.label,
      required this.filled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Theme.of(context).colorScheme.secondary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
                color: filled ? Theme.of(context).colorScheme.secondary : Colors.black26, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  color: filled ? Theme.of(context).cardColor : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      ),
    );
  }
}



// ── Fish / cross easter egg ───────────────────────────────────────────────────
class _FishCross extends StatefulWidget {
  const _FishCross();
  @override
  State<_FishCross> createState() => _FishCrossState();
}

class _FishCrossState extends State<_FishCross>
    with SingleTickerProviderStateMixin {
  bool _isCross = false;
  late AnimationController _ctrl;
  late Animation<double> _jump;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350));
    _jump = Tween<double>(begin: 0, end: -16).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () {}, child: Text('Terms', style: TextStyle(fontSize: 11, color: Colors.black26))),
            const Text('•', style: TextStyle(color: Colors.black12, fontSize: 10)),
            TextButton(onPressed: () {}, child: Text('Privacy', style: TextStyle(fontSize: 11, color: Colors.black26))),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('built with faith  ',
                style: TextStyle(fontSize: 11, color: Colors.black26)),
            GestureDetector(
              onTap: () {
                _ctrl.forward(from: 0);
                Future.delayed(const Duration(milliseconds: 175), () {
                  if (mounted) setState(() => _isCross = !_isCross);
                });
              },
              child: AnimatedBuilder(
                animation: _jump,
                builder: (_, child) => Transform.translate(
                    offset: Offset(0, _jump.value), child: child),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isCross
                      ? const Text('✝️', key: ValueKey('cross'), style: TextStyle(fontSize: 16))
                      : const Icon(Icons.set_meal_outlined, // Better than text for fish
                          key: ValueKey('fish'),
                          size: 16,
                          color: Colors.black26),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
