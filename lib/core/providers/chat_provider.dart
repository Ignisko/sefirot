import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_model.dart';

final userChatsProvider = StreamProvider.autoDispose.family<List<ChatModel>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
    final chats = snapshot.docs.map((doc) => ChatModel.fromMap(doc.data(), doc.id)).toList();
    debugPrint('[CHATS] Fetched ${chats.length} chats for $uid');
    // Sort client-side by lastTimestamp descending
    chats.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return chats;
  });
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  final _firestore = FirebaseFirestore.instance;

  Future<void> archiveChat(String chatId, String uid) async {
    await _firestore.collection('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayUnion([uid])
    });
  }

  Future<void> unarchiveChat(String chatId, String uid) async {
    await _firestore.collection('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayRemove([uid])
    });
  }
}
