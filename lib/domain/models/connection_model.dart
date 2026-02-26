import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { pending, accepted, rejected }

class ConnectionModel {
  final String id;
  // userIds contains exactly two elements: [senderId, receiverId]
  // This allows O(1) matching using array-contains queries.
  final List<String> userIds;
  final String senderId;
  final ConnectionStatus status;
  final DateTime updatedAt;

  ConnectionModel({
    required this.id,
    required this.userIds,
    required this.senderId,
    this.status = ConnectionStatus.pending,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userIds': userIds,
      'senderId': senderId,
      'status': status.name,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ConnectionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ConnectionModel(
      id: documentId,
      userIds: List<String>.from(map['userIds'] ?? []),
      senderId: map['senderId'] ?? '',
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ConnectionStatus.pending,
      ),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  ConnectionModel copyWith({
    ConnectionStatus? status,
  }) {
    return ConnectionModel(
      id: id,
      userIds: userIds,
      senderId: senderId,
      status: status ?? this.status,
      updatedAt: DateTime.now(),
    );
  }
}
