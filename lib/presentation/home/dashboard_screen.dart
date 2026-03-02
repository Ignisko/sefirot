import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/models/user_model.dart';

// ── Dashboard Screen ──────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  final void Function(int tab) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We only need the user info for the greeting
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null ? 'Hello, ${user.displayName}' : 'Welcome to Pelegrin',
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your journey to Seoul 2027 starts here',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                ),
                const SizedBox(height: 48),
                
                // Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('SEOUL 2027', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'World Youth Day',
                              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Join thousands of young Catholics gathering in South Korea to celebrate our faith and shape the future.',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, height: 1.5),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: () => onNavigate(1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 0,
                              ),
                               child: const Text('Discover Pilgrims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            )
                          ],
                        ),
                      ),
                      // Graphic on the right (hidden on very small screens, but we have max-width constraint anyway)
                      const SizedBox(width: 40),
                      const Icon(Icons.public, size: 160, color: Colors.white24),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Quick Links
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          _StatCard(
                            icon: Icons.person_pin,
                            title: 'Your Profile',
                            subtitle: 'View your bio',
                            color: Colors.blue.shade100,
                            iconColor: Colors.blue.shade700,
                            onTap: () => onNavigate(3),
                          ),
                          const SizedBox(height: 16),
                          _StatCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'Messages',
                            subtitle: 'Check your inbox',
                            color: Colors.orange.shade100,
                            iconColor: Colors.orange.shade700,
                            onTap: () => onNavigate(2),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.person_pin,
                            title: 'Your Profile',
                            subtitle: 'View your bio',
                            color: Colors.blue.shade100,
                            iconColor: Colors.blue.shade700,
                            onTap: () => onNavigate(3),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'Messages',
                            subtitle: 'Check your inbox',
                            color: Colors.orange.shade100,
                            iconColor: Colors.orange.shade700,
                            onTap: () => onNavigate(2),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.info_outline,
                            title: 'About WYD',
                            subtitle: 'Learn more',
                            color: Colors.green.shade100,
                            iconColor: Colors.green.shade700,
                            onTap: () => onNavigate(4),
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
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _StatCard({
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
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                ]
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

