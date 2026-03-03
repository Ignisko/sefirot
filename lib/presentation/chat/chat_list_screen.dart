import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import 'chat_screen.dart';
import '../../domain/models/chat_model.dart';
import '../browse/browse_screen.dart';
import '../../core/providers/chat_provider.dart';

// ── Chat List Screen ──────────────────────────────────────────────────────────
class ChatListScreen extends ConsumerStatefulWidget {
  final String? preselectedConversationId;
  const ChatListScreen({super.key, this.preselectedConversationId});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _didAutoOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      body: DefaultTabController(
        length: 2,
        child: chatsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (chatsAll) {
            // First apply search
            final searched = chatsAll.where((c) {
                if (_searchQuery.isEmpty) return true;
                final peerUid = c.participants.firstWhere((p) => p != myUid, orElse: () => '');
                // The actual name matching is tricky here without peer names in chat_model
                // For a robust search, we need a stream of user names. 
                // We'll leave the search query filter open since Sefirot doesn't denormalize names yet.
                // Assuming it filters globally.
                return true; 
            }).toList();

            final mainChats = searched.where((c) => !c.archivedBy.contains(myUid)).toList();
            final archivedChats = searched.where((c) => c.archivedBy.contains(myUid)).toList();

            return Column(
              children: [
                // ── Search Bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black38),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),

                // ── Tab Bar ────────────────────────────────────────────────
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Main'),
                    Tab(text: 'Archived'),
                  ],
                ),
                
                // ── Tab Bar View ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(mainChats, myUid, myBlockedUids),
                      _buildList(archivedChats, myUid, myBlockedUids),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<ChatModel> list, String myUid, List<String> myBlockedUids) {
    if (list.isEmpty) return _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, index) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (_, i) {
        final chat = list[i];
        final peerUid = chat.participants.firstWhere((p) => p != myUid, orElse: () => '');
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
          chat: chat,
          peerUid: peerUid,
          myUid: myUid,
          myBlockedUids: myBlockedUids,
          isUnread: chat.lastMessageSeenBy[myUid] == false,
          isArchived: chat.archivedBy.contains(myUid),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
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
}

// ── Chat tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String peerUid;
  final String myUid;
  final List<String> myBlockedUids;
  final bool isUnread;
  final bool isArchived;

  const _ChatTile({
    required this.chat,
    required this.peerUid,
    required this.myUid,
    required this.myBlockedUids,
    required this.isUnread,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        return Dismissible(
          key: Key(chat.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: isArchived ? Colors.blue : Colors.orange,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(isArchived ? Icons.unarchive : Icons.archive, color: Colors.white),
          ),
          onDismissed: (_) async {
            final repo = ref.read(chatRepositoryProvider);
            if (isArchived) {
              await repo.unarchiveChat(chat.id, myUid);
            } else {
              await repo.archiveChat(chat.id, myUid);
            }
          },
          child: Material(
            color: Theme.of(context).cardColor,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => showProfileDetail(context, peer),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withOpacity(0.12),
                      backgroundImage: peer.photoUrl.isNotEmpty
                          ? NetworkImage(peer.photoUrl)
                          : null,
                      child: peer.photoUrl.isEmpty
                          ? Text(initials,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 18))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 3),
                        Text(
                          chat.lastMessage.isNotEmpty ? chat.lastMessage : 'Start chatting…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              color: isUnread 
                                  ? Theme.of(context).colorScheme.onSurface
                                  : (chat.lastMessage.isNotEmpty ? Colors.black54 : Colors.black26),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unread indicator and Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chat.lastMessageTime != null)
                        Text(_formatTime(chat.lastMessageTime!),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black38)),
                      if (isUnread) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('New',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
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
