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

// ── Providers ─────────────────────────────────────────────────────────────────
final paxesProvider = StreamProvider.family<List<DocumentSnapshot>, String>((ref, myUid) {
  return FirebaseFirestore.instance
      .collection('paxes')
      .where('toUid', isEqualTo: myUid)
      .snapshots()
      .map((snap) => snap.docs);
});

// ── Chat List Screen ──────────────────────────────────────────────────────────
class ChatListScreen extends ConsumerStatefulWidget {
  final String? preselectedConversationId;
  const ChatListScreen({super.key, this.preselectedConversationId});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

enum _ChatFilter { all, unread, unanswered }

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _didAutoOpen = false;
  _ChatFilter _filter = _ChatFilter.all;

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
        length: 3,
        child: chatsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (chatsAll) {
            final paxesAsync = ref.watch(paxesProvider(myUid));
            final paxesList = paxesAsync.value ?? [];
            
            // Apply search — filter by peer user data loaded from chat participants
            final searched = _searchQuery.isEmpty
                ? chatsAll
                : chatsAll.where((chat) {
                    // Match against the chat's last message or participant UIDs stored in chat metadata
                    // We check lastMessage text and the chat ID for a quick client-side filter.
                    // Peer name matching happens in the tile, but we can filter on lastMessage here.
                    final lastMsg = chat.lastMessage.toLowerCase();
                    final q = _searchQuery;
                    // Also check the peer UID substring (allows searching by uid prefix if needed)
                    final peerUid = chat.participants.firstWhere(
                      (p) => p != myUid,
                      orElse: () => '',
                    );
                    return lastMsg.contains(q) || peerUid.toLowerCase().contains(q);
                  }).toList();

            final mainChats = searched.where((c) => !c.archivedBy.contains(myUid)).toList();
            final archivedChats = searched.where((c) => c.archivedBy.contains(myUid)).toList();

            // Apply filters to main chats only
            final filteredMain = mainChats.where((c) {
              if (_filter == _ChatFilter.unread) {
                return c.lastMessageSeenBy[myUid] == false;
              }
              if (_filter == _ChatFilter.unanswered) {
                // Unanswered = last message was NOT sent by me (i.e. peer sent last)
                return c.lastMessageSenderUid != myUid &&
                    c.lastMessage.isNotEmpty &&
                    c.lastMessageSeenBy[myUid] == false;
              }
              return true;
            }).toList();

            return Column(
              children: [
                // ── Search Bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

                // ── Filter Chips ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      _filterChip('All', _ChatFilter.all),
                      const SizedBox(width: 8),
                      _filterChip('Unread', _ChatFilter.unread),
                      const SizedBox(width: 8),
                      _filterChip('Unanswered', _ChatFilter.unanswered),
                    ],
                  ),
                ),

                // ── Tab Bar ────────────────────────────────────────────────
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Main (${filteredMain.length})'),
                    Tab(text: 'Paxes (${paxesList.length})'),
                    Tab(text: 'Archived (${archivedChats.length})'),
                  ],
                ),

                // ── Tab Bar View ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(filteredMain, myUid, myBlockedUids, archived: false),
                      _PaxesList(paxesList, myUid, myBlockedUids),
                      _buildList(archivedChats, myUid, myBlockedUids, archived: true),
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

  Widget _filterChip(String label, _ChatFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<ChatModel> list, String myUid, List<String> myBlockedUids, {required bool archived}) {
    if (list.isEmpty) return _EmptyState(archived: archived, filter: _filter);
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
                // ignore: use_build_context_synchronously
                if (!context.mounted) return;
                final peer = UserModel.fromMap(snap.data() as Map<String, dynamic>, peerUid);
                // ignore: use_build_context_synchronously
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
  final bool archived;
  final bool isPaxes;
  final _ChatFilter filter;
  const _EmptyState({this.archived = false, this.isPaxes = false, this.filter = _ChatFilter.all});

  @override
  Widget build(BuildContext context) {
    final msg = isPaxes
        ? 'No Paxes yet'
        : archived
            ? 'No archived conversations'
            : filter == _ChatFilter.unread
                ? 'No unread messages'
                : filter == _ChatFilter.unanswered
                    ? 'No unanswered messages'
                    : 'No conversations yet';
    final sub = isPaxes
        ? 'When pilgrims send you a Pax greeting, it will appear here.'
        : archived
            ? 'Swipe left on a message to archive it.'
            : 'Browse pilgrims and hit "Connect" to start chatting.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaxes ? Icons.spa_outlined : archived ? Icons.archive_outlined : Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(msg,
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45)),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black38, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Paxes List ────────────────────────────────────────────────────────────────
class _PaxesList extends StatelessWidget {
  final List<DocumentSnapshot> paxes;
  final String myUid;
  final List<String> myBlockedUids;
  
  const _PaxesList(this.paxes, this.myUid, this.myBlockedUids);

  @override
  Widget build(BuildContext context) {
    if (paxes.isEmpty) return const _EmptyState(isPaxes: true);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: paxes.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (_, i) {
        final pax = paxes[i];
        final fromUid = pax['fromUid'] as String;
        return _PaxTile(fromUid: fromUid, myUid: myUid, paxId: pax.id, myBlockedUids: myBlockedUids);
      },
    );
  }
}

class _PaxTile extends StatelessWidget {
  final String fromUid;
  final String myUid;
  final String paxId;
  final List<String> myBlockedUids;

  const _PaxTile({required this.fromUid, required this.myUid, required this.paxId, required this.myBlockedUids});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox(height: 64);
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final peer = UserModel.fromMap(data, fromUid);

        // Hide blocked chats
        if (myBlockedUids.contains(fromUid) || peer.blockedUids.contains(myUid)) {
          return const SizedBox.shrink();
        }

        final name = peer.displayName.isNotEmpty ? peer.displayName : peer.email.split('@').first;
        final initials = name[0].toUpperCase();
        final isVol = peer.accountType == 'volunteer';
        final color = isVol ? const Color(0xFFCD2E3A) : Theme.of(context).colorScheme.secondary;

        return Material(
          color: Theme.of(context).cardColor,
          child: InkWell(
            onTap: () => showProfileDetail(context, peer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.12),
                  backgroundImage: peer.photoUrl.isNotEmpty ? NetworkImage(peer.photoUrl) : null,
                  child: peer.photoUrl.isEmpty
                      ? Text(initials, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 3),
                      const Text(
                        'Sent you a Pax',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.spa_outlined, color: Theme.of(context).colorScheme.secondary),
              ]),
            ),
          ),
        );
      },
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
          key: Key('${chat.id}_$isArchived'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: isArchived ? Colors.blue.shade600 : Colors.orange.shade600,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  isArchived ? 'Restore' : 'Archive',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            final repo = ref.read(chatRepositoryProvider);
            if (isArchived) {
              await repo.unarchiveChat(chat.id, myUid);
            } else {
              await repo.archiveChat(chat.id, myUid);
            }
            return false; // don't remove from list — riverpod will update
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
                  // Avatar — tap to see profile
                  GestureDetector(
                    onTap: () => showProfileDetail(context, peer),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withValues(alpha: 0.12),
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

                  // Right area: time + unread badge
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
                      // Archive/restore icon hint
                      const SizedBox(height: 4),
                      Icon(
                        isArchived ? Icons.unarchive_rounded : Icons.swipe_left_rounded,
                        size: 14,
                        color: Colors.black26,
                      ),
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
