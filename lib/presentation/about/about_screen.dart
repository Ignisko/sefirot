import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────
                Text('Our Mission',
                    style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Franciscan Spirit ───────────────────────
                _Section(
                  icon: Icons.spa_outlined,
                  title: 'Pax et Bonum',
                  text: 'Pelegrin is built on the Franciscan spirit of "Peace and Good." As we journey toward World Youth Day Seoul 2027, we aim to foster a community of pilgrims who support, pray, and walk together.',
                ),

                const SizedBox(height: 32),

                // ── Seoul 2027 ──────────────────────────────
                _Section(
                  icon: Icons.public_rounded,
                  title: 'The Road to Seoul',
                  text: 'World Youth Day is more than just an event; it\'s a spiritual milestone. This platform helps you find travel companions, shared accommodation, and fellow pilgrims from your own country or across the globe.',
                ),

                const SizedBox(height: 32),

                // ── Community ───────────────────────────────
                _Section(
                  icon: Icons.diversity_3_outlined,
                  title: 'Safe & Sacred Support',
                  text: 'We are committed to providing a safe space for interaction. Whether you are a first-time pilgrim or a seasoned volunteer, Pelegrin connects you with the heart of the Church.',
                ),

                const SizedBox(height: 60),

                // ── Simple Footer ───────────────────────────
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => launchUrl(Uri.parse('https://pelegrin.cloud/terms')),
                            child: Text('Terms', 
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                          ),
                          const Text('•', style: TextStyle(color: Colors.black12)),
                          TextButton(
                            onPressed: () => launchUrl(Uri.parse('https://pelegrin.cloud/privacy')),
                            child: Text('Privacy', 
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Made in Poland for Seoul 2027',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black26,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('v1.0.3', 
                          style: TextStyle(fontSize: 11, color: Colors.black12)),
                    ],
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

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Section({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black54,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
