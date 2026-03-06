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
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
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
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your journey to Seoul 2027 starts here',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('SEOUL 2027', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'World Youth Day',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Join thousands of young Catholics gathering in South Korea to celebrate our faith and shape the future.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 17, height: 1.5),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: () => onNavigate(1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 0,
                              ),
                               child: const Text('Discover Pilgrims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      if (MediaQuery.of(context).size.width > 700)
                        Icon(Icons.public, size: 160, color: Colors.white.withValues(alpha: 0.2)),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Quick Links Group
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 3 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isWide ? 1.3 : 2.2,
                      children: [
                        _QuickLinkCard(
                          icon: Icons.person_pin,
                          title: 'Your Profile',
                          subtitle: 'View your bio',
                          color: Colors.blue.shade50,
                          iconColor: Colors.blue.shade700,
                          onTap: () => onNavigate(3),
                        ),
                        _QuickLinkCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'Messages',
                          subtitle: 'Check your inbox',
                          color: Colors.orange.shade50,
                          iconColor: Colors.orange.shade700,
                          onTap: () => onNavigate(2),
                        ),
                        _QuickLinkCard(
                          icon: Icons.search,
                          title: 'Browse',
                          subtitle: 'Find connections',
                          color: Colors.pink.shade50,
                          iconColor: const Color(0xFFE11D48),
                          onTap: () => onNavigate(1),
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
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: iconColor.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

