import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_model.dart';

final userChatsProvider = StreamProvider.autoDispose.family<List<ChatModel>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: uid)
      .orderBy('lastTimestamp', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ChatModel.fromMap(doc.data(), doc.id)).toList();
  });
});
