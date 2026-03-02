import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, dynamic> lastMessageSeenBy;
  final List<String> archivedBy;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageSeenBy,
    this.archivedBy = const [],
  });

  factory ChatModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ChatModel(
      id: documentId,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastTimestamp'] != null
          ? (data['lastTimestamp'] as Timestamp).toDate()
          : null,
      lastMessageSeenBy: Map<String, dynamic>.from(data['lastMessageSeenBy'] ?? {}),
      archivedBy: List<String>.from(data['archivedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastTimestamp': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : FieldValue.serverTimestamp(),
      'lastMessageSeenBy': lastMessageSeenBy,
      'archivedBy': archivedBy,
    };
  }
}
