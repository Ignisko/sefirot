import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/user_provider.dart';

// ── Dashboard Screen ──────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  final void Function(int tab) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user != null ? 'Hello, ${user.displayName}' : 'Welcome to Pelegrin',
                          style: GoogleFonts.outfit(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your journey to Seoul 2027 starts here',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B), 
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(52),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          blurRadius: 50,
                          offset: const Offset(0, 25),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: const Text('SOUTH KOREA 2027', 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2.0)),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'World Youth Day',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2.0),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Join thousands of young Catholics gathering in South Korea to celebrate our faith and shape the future.',
                                style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.9), fontSize: 20, height: 1.5, fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 44),
                              ElevatedButton(
                                onPressed: () => onNavigate(1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  elevation: 0,
                                ),
                                 child: const Text('Discover Pilgrims', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        if (MediaQuery.of(context).size.width > 850)
                          Icon(Icons.public_rounded, size: 240, color: Colors.white.withValues(alpha: 0.12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Quick Links
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: _QuickLinkCard(
                              icon: Icons.search_rounded,
                              title: 'Browse Pilgrims',
                              subtitle: 'Find connections',
                              gradient: const [Color(0xFFFDA4AF), Color(0xFFE11D48)],
                              onTap: () => onNavigate(1),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _QuickLinkCard(
                              icon: Icons.person_rounded,
                              title: 'Your Profile',
                              subtitle: 'View your bio',
                              gradient: const [Color(0xFFBAE6FD), Color(0xFF0EA5E9)],
                              onTap: () => onNavigate(3),
                            ),
                          ),
                        ],
                      );
                    }
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

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [gradient[0], gradient[1].withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[1].withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Organic Wave backgrounds
            Positioned(
              right: -50,
              bottom: -40,
              child: Opacity(
                opacity: 0.2,
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              top: -60,
              child: Opacity(
                opacity: 0.1,
                child: RotationTransition(
                  turns: const AlwaysStoppedAnimation(180 / 360),
                  child: ClipPath(
                    clipper: _WaveClipper(),
                    child: Container(
                      width: 180,
                      height: 180,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: gradient[1], size: 24),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.8);
    
    var firstControlPoint = Offset(size.width * 0.25, size.height);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width * 0.75, size.height * 0.6);
    var secondEndPoint = Offset(size.width, size.height * 0.8);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


