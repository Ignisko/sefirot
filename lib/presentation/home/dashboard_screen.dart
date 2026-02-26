import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../domain/models/chat_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────







final _pilgrimCountProvider = StreamProvider.autoDispose<int>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  if (userAsync.value?.isAdmin == true) {
    return FirebaseFirestore.instance
        .collection('users')
        .count()
        .get()
        .then((s) => s.count ?? 0)
        .asStream();
  }
  return Stream.value(0); // Regular users don't need the exact count
});
// ── Dashboard Screen ──────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  final void Function(int tab) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final countAsync = ref.watch(_pilgrimCountProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final chatsAsync = ref.watch(userChatsProvider(myUid));

    final pilgrimCount = countAsync.whenOrNull(data: (c) => c) ?? 0;
    // Limit to 6 unread chats for the dashboard
    final pendingChats = (chatsAsync.whenOrNull(data: (c) => c) ?? [])
        .where((chat) => chat.lastMessage.isNotEmpty)
        .take(6)
        .toList();
    final isAdmin = ref.watch(currentUserModelProvider).value?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isWide
          ? _wideLayout(context, ref, myUid, pilgrimCount, pendingChats, isAdmin)
          : _narrowLayout(context, ref, myUid, pilgrimCount, pendingChats, isAdmin),
    );
  }

  // ── Desktop: two-column ───────────────────────────────────────────────────
  Widget _wideLayout(BuildContext context, WidgetRef ref,
      String myUid, int count, List<ChatModel> chats, bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 36, 36, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilgrim Matching Dashboard',
              style: GoogleFonts.outfit(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          const Text(
            'Seoul 2027 · Connect · Journey together',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main column
              Expanded(
                flex: 3,
                child: Column(children: [
                  _PilgrimsQueueCard(count: count, onBrowse: () => onNavigate(1), isAdmin: isAdmin),
                  const SizedBox(height: 16),
                  _PendingChatsCard(
                    chats: chats,
                    myUid: myUid,
                    onMessages: () => onNavigate(2),
                  ),
                  const SizedBox(height: 16),
                  _ProfileTipsCard(onProfile: () => onNavigate(3)),
                ]),
              ),
              const SizedBox(width: 20),
              // Right column
              SizedBox(
                width: 280,
                child: Column(children: [
                  _HowItWorksCard(),
                  const SizedBox(height: 16),
                  _StatsCard(count: count, chats: chats, isAdmin: isAdmin),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mobile: single column ─────────────────────────────────────────────────
  Widget _narrowLayout(BuildContext context, WidgetRef ref,
      String myUid, int count, List<ChatModel> chats, bool isAdmin) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('Dashboard',
            style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const Text('Seoul 2027 Pilgrim Matching',
            style: TextStyle(color: Colors.black38, fontSize: 13)),
        const SizedBox(height: 20),
        _PilgrimsQueueCard(count: count, onBrowse: () => onNavigate(1), isAdmin: isAdmin),
        const SizedBox(height: 12),
        _PendingChatsCard(
            chats: chats, myUid: myUid, onMessages: () => onNavigate(2)),
        const SizedBox(height: 12),
        _HowItWorksCard(),
        const SizedBox(height: 12),
        _StatsCard(count: count, chats: chats, isAdmin: isAdmin),
        const SizedBox(height: 12),
        _ProfileTipsCard(onProfile: () => onNavigate(3)),
      ],
    );
  }
}

class _PilgrimsQueueCard extends StatelessWidget {
  final int count;
  final VoidCallback onBrowse;
  final bool isAdmin;
  const _PilgrimsQueueCard({required this.count, required this.onBrowse, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🔍', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                      children: [
                        TextSpan(
                          text: isAdmin ? '$count pilgrims ' : 'Many pilgrims ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                        ),
                        const TextSpan(
                            text:
                                'are heading to Seoul 2027 and may be a match for you!'),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onBrowse,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                child: Text('Browse Pilgrims',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Card: pending chat connections ────────────────────────────────────────────
class _PendingChatsCard extends StatelessWidget {
  final List<ChatModel> chats;
  final String myUid;
  final VoidCallback onMessages;
  const _PendingChatsCard({
    required this.chats,
    required this.myUid,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    final n = chats.length;
    return _Card(
      child: Column(children: [
        // Avatar cluster
        if (n > 0) ...[ 
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(n.clamp(0, 5), (i) {
                final chat = chats[i];
                final uid = chat.participants.firstWhere(
                    (p) => p != myUid,
                    orElse: () => '');
                return Positioned(
                  left: i * 32.0,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.primary,
                      const Color(0xFF2E7D32),
                      const Color(0xFF6A1B9A),
                      const Color(0xFF00838F),
                    ][i % 5],
                    child: Text(
                      uid.isNotEmpty ? uid[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          n == 0
              ? 'No pending conversations yet.'
              : 'You have $n connection${n == 1 ? '' : 's'} you haven\'t replied to yet.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        if (n > 0) ...[ 
          const SizedBox(height: 6),
          Text(
            'Keep the journey moving! Pilgrims connect best\nwithin the first few days of matching.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.secondary, height: 1.5),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Browse pilgrims and hit Connect to start a conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onMessages,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black26),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
          ),
          child: Text('Open Messages',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Card: profile completion tips ─────────────────────────────────────────────
class _ProfileTipsCard extends StatelessWidget {
  final VoidCallback onProfile;
  const _ProfileTipsCard({required this.onProfile});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(children: [
        const Text('🙏', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Complete your pilgrim profile',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 3),
              const Text(
                'Pilgrims with complete profiles get 3× more connection requests.',
                style: TextStyle(
                    fontSize: 12, color: Colors.black45, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onProfile,
          child: Text('Edit →',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Right panel: How it Works ─────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it Works',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          ...[
            ('🔍', 'Browse',
                'Discover pilgrims heading to Seoul 2027 who match your journey plans.'),
            ('🤝', 'Connect',
                'Send a connection request. They\'ll receive your profile by email.'),
            ('💬', 'Message',
                'Once accepted, chat directly. Plan routes, share accommodations, pray together.'),
          ].map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.$1,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(e.$3,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int count;
  final List<ChatModel> chats;
  final bool isAdmin;
  const _StatsCard({required this.count, required this.chats, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Community',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 12),
          _StatRow('Registered pilgrims', isAdmin ? '$count' : 'Growing daily!'),
          _StatRow('Your conversations', '${chats.length}'),
          _StatRow('Event', 'Seoul 2027'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Text('✝', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is an early community. Invite other pilgrims!',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface)),
      ]),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
