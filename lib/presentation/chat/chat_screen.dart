import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/matchmaking_provider.dart';
import '../admin/user_actions_helper.dart';
import '../browse/browse_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────






// ── Helpers ───────────────────────────────────────────────────────────────────
String chatId(String uid1, String uid2) {
  final sorted = [uid1, uid2]..sort();
  return sorted.join('_');
}

// ── Rate-limit guardrail (client-side, backed by Firestore rules too) ─────────
/// Returns true if the user has already sent ≥ 40 messages today.
Future<bool> _isRateLimited(String uid) async {
  final today = DateTime.now();
  final dayStart = DateTime(today.year, today.month, today.day);
  final snap = await FirebaseFirestore.instance
      .collectionGroup('messages')
      .where('senderUid', isEqualTo: uid)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .count()
      .get();
  return (snap.count ?? 0) >= 40;
}

// ── Chat Screen ───────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final UserModel peer;
  const ChatScreen({super.key, required this.peer});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  late String _chatId;
  late String _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = ref.read(authRepositoryProvider).currentUser!.uid;
    _chatId = chatId(_myUid, widget.peer.uid);
    _ensureChatDoc();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureChatDoc() async {
    final docRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final snap = await docRef.get();
    if (!snap.exists) {
      await ref.read(matchmakingRepositoryProvider).createChat([_myUid, widget.peer.uid]);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 500) {
      _snack('Message too long (max 500 characters)');
      return;
    }

    setState(() => _sending = true);
    try {
      // Client-side rate limit check
      if (await _isRateLimited(_myUid)) {
        _snack('Daily message limit reached (40/day). Come back tomorrow.');
        return;
      }

      // Chat doc is guaranteed by _ensureChatDoc() called in initState.
      // No need to call it again here.
      await ref.read(matchmakingRepositoryProvider).sendMessage(_chatId, _myUid, text);
      _ctrl.clear();
      _scrollToBottom();
    } catch (e) {
      _snack('Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _peerName() {
    final n = widget.peer.displayName;
    return n.isNotEmpty ? n : widget.peer.email.split('@').first;
  }

  String _peerInitials() {
    final n = widget.peer.displayName;
    if (n.isNotEmpty) {
      final p = n.trim().split(' ');
      return p.length >= 2
          ? '${p[0][0]}${p[1][0]}'.toUpperCase()
          : p[0][0].toUpperCase();
    }
    return widget.peer.email[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = _peerName();
    final initials = _peerInitials();
    final isVol = widget.peer.accountType == 'volunteer';
    final color = isVol ? const Color(0xFFCD2E3A) : Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Text('←', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showProfileDetail(context, widget.peer, hideConnectButton: true),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                backgroundImage: widget.peer.photoUrl.isNotEmpty
                    ? NetworkImage(widget.peer.photoUrl)
                    : null,
                child: widget.peer.photoUrl.isEmpty
                    ? Text(initials,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: color))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                  if (widget.peer.nationality.isNotEmpty)
                    Text(widget.peer.nationality,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => UserActionsHelper.showOptions(context, ref, widget.peer),
          ),
        ],
      ),
      body: Column(children: [
        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(_chatId)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.message_outlined, size: 40, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                        const SizedBox(height: 12),
                        Text('Start the conversation',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black45)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Say hello to $name',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black38)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black26),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              // Mark unread messages as read, scheduled after the frame to
              // avoid triggering Firestore writes on every widget repaint.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['senderUid'] != _myUid && data['read'] == false) {
                    doc.reference.update({'read': true});
                  }
                }
              });
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderUid'] == _myUid;
                  final ts = data['timestamp'] as Timestamp?;
                  return _Bubble(
                    text: data['text'] ?? '',
                    isMe: isMe,
                    timestamp: ts?.toDate(),
                    read: data['read'] ?? false,
                  );
                },
              );
            },
          ),
        ),

        // Input bar
        Container(
          color: Theme.of(context).cardColor,
          padding: EdgeInsets.only(
            left: 16, right: 12, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    currentLength > 450
                        ? Text('$currentLength/$maxLength',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black38))
                        : null,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _sending ? Colors.black12 : Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? SizedBox(
                        width: 18, height: 18,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Theme.of(context).cardColor, strokeWidth: 2)))
                    : Center(
                        child: Text('→',
                            style: TextStyle(
                                color: Theme.of(context).cardColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe, read;
  final DateTime? timestamp;
  const _Bubble({
    required this.text,
    required this.isMe,
    required this.read,
    this.timestamp,
  });

  String _time(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.secondary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text,
                style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Theme.of(context).cardColor : Theme.of(context).colorScheme.onSurface,
                    height: 1.4)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_time(timestamp),
                    style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Theme.of(context).cardColor.withValues(alpha: 0.6)
                            : Colors.black26)),
                if (isMe) ...[ 
                  const SizedBox(width: 4),
                  Text(read ? '✓✓' : '✓',
                      style: TextStyle(
                          fontSize: 10,
                          color: read
                              ? Theme.of(context).cardColor.withValues(alpha: 0.9)
                              : Theme.of(context).cardColor.withValues(alpha: 0.5))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
