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
    // We only need the user info for the greeting
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => onNavigate(3), // Navigate to Profile
                  child: Text(
                    user != null ? 'Hello, ${user.displayName}' : 'Welcome to Pelegrin',
                    style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your journey to Seoul 2027 starts here',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                ),
                const SizedBox(height: 48),
                
                // Quick Links
                LayoutBuilder(
                  builder: (context, constraints) {
                    final children = [
                      _StatCard(
                        icon: Icons.search,
                        title: 'Browse Pilgrims',
                        subtitle: 'Find connections',
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        iconColor: Theme.of(context).colorScheme.primary,
                        onTap: () => onNavigate(1),
                      ),
                      const SizedBox(height: 16, width: 24),
                      _StatCard(
                        icon: Icons.person_pin,
                        title: 'Your Profile',
                        subtitle: 'View your bio',
                        color: Colors.blue.shade100,
                        iconColor: Colors.blue.shade700,
                        onTap: () => onNavigate(3),
                      ),
                    ];

                    if (constraints.maxWidth < 600) {
                      return Column(children: children);
                    }
                    return Row(
                      children: children.whereType<Widget>().map((w) => w is _StatCard ? Expanded(child: w) : w).toList(),
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
          color: color.withValues(alpha: 0.3),
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
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
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

