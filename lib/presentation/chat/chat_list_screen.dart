import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import 'chat_screen.dart';






import '../../core/providers/chat_provider.dart';

// ── Chat List Screen ──────────────────────────────────────────────────────────
class ChatListScreen extends ConsumerStatefulWidget {
  final String? preselectedConversationId;
  const ChatListScreen({super.key, this.preselectedConversationId});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _didAutoOpen = false;

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final chatsAsync = ref.watch(userChatsProvider(myUid));
    final myUserAsync = ref.watch(userProfileProvider(myUid));
    final myBlockedUids = myUserAsync.value?.blockedUids ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text('Messages',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text('No conversations yet',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black45)),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse pilgrims and hit\n"Connect" to start chatting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black38, fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, index) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (_, i) {
              final chat = chats[i];
              final peerUid =
                  chat.participants.firstWhere((p) => p != myUid, orElse: () => '');
              if (peerUid.isEmpty) return const SizedBox();
              
              // Handle deep link auto-open exactly once per load
              if (widget.preselectedConversationId == chat.id && !_didAutoOpen) {
                _didAutoOpen = true;
                Future.microtask(() async {
                   final snap = await FirebaseFirestore.instance.collection('users').doc(peerUid).get();
                   if (snap.exists) {
                     if (!context.mounted) return;
                     final peer = UserModel.fromMap(snap.data() as Map<String, dynamic>, peerUid);
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)));
                   }
                });
              }

              return _ChatTile(
                peerUid: peerUid,
                lastMsg: chat.lastMessage,
                timestamp: chat.lastMessageTime,
                myUid: myUid,
                myBlockedUids: myBlockedUids,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String peerUid, lastMsg, myUid;
  final DateTime? timestamp;
  final List<String> myBlockedUids;

  const _ChatTile({
    required this.peerUid,
    required this.lastMsg,
    required this.myUid,
    required this.myBlockedUids,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(peerUid).get(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 64);
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final peer = UserModel.fromMap(data, peerUid);

        // Hide blocked chats
        if (myBlockedUids.contains(peerUid) || peer.blockedUids.contains(myUid)) {
          return const SizedBox.shrink();
        }

        final name = peer.displayName.isNotEmpty
            ? peer.displayName
            : peer.email.split('@').first;
        final initials = name[0].toUpperCase();
        final isVol = peer.accountType == 'volunteer';
        final color = isVol ? const Color(0xFFCD2E3A) : Theme.of(context).colorScheme.secondary;

        return Material(
          color: Theme.of(context).cardColor,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.12),
                  backgroundImage: peer.photoUrl.isNotEmpty
                      ? NetworkImage(peer.photoUrl)
                      : null,
                  child: peer.photoUrl.isEmpty
                      ? Text(initials,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 16))
                      : null,
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        lastMsg.isNotEmpty ? lastMsg : 'Start chatting…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: lastMsg.isNotEmpty
                                ? Colors.black54
                                : Colors.black26),
                      ),
                    ],
                  ),
                ),

                // Time
                if (timestamp != null)
                  Text(_formatTime(timestamp!),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38)),
              ]),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
