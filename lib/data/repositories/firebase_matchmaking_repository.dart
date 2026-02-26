import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/match_preference_model.dart';
import '../../domain/models/connection_model.dart';
import '../../domain/repositories/matchmaking_repository.dart';

class FirebaseMatchmakingRepository implements MatchmakingRepository {
  final FirebaseFirestore _firestore;

  FirebaseMatchmakingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<MatchPreferenceModel?> getMatchPreference(String uid) {
    return _firestore
        .collection('match_preferences')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return MatchPreferenceModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  @override
  Future<void> updateMatchPreference(MatchPreferenceModel preference) async {
    await _firestore
        .collection('match_preferences')
        .doc(preference.userId)
        .set(preference.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> createOrUpdateConnection({
    required String senderId,
    required String receiverId,
    required ConnectionStatus status,
  }) async {
    // Generate a consistent ID regardless of who swiped first
    // e.g. "userA_userB" where A < B alphabetically
    final ids = [senderId, receiverId]..sort();
    final connectionId = '${ids[0]}_${ids[1]}';

    final connectionRef = _firestore.collection('connections').doc(connectionId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(connectionRef);

      if (!snapshot.exists) {
        // Create new pending connection
        final newConnection = ConnectionModel(
          id: connectionId,
          userIds: [senderId, receiverId],
          senderId: senderId,
          status: status,
        );
        transaction.set(connectionRef, newConnection.toMap());
      } else {
        // Evaluate mutual swipe right (both accepted)
        final existing = ConnectionModel.fromMap(snapshot.data()!, snapshot.id);

        if (existing.senderId != senderId && status == ConnectionStatus.accepted && existing.status == ConnectionStatus.accepted) {
          // It's a match! 
          transaction.update(connectionRef, {
            'status': ConnectionStatus.accepted.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (status == ConnectionStatus.rejected) {
          // If anyone rejects, the connection is burned
           transaction.update(connectionRef, {
            'status': ConnectionStatus.rejected.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  @override
  Stream<List<ConnectionModel>> getPendingConnections(String uid) {
    // Queries all connections where uid is in userIds, but uid is NOT the sender,
    // and status == pending. Means the other person swiped right.
    return _firestore
        .collection('connections')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: ConnectionStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConnectionModel.fromMap(doc.data(), doc.id))
          .where((conn) => conn.senderId != uid) // Filter out ones we sent
          .toList();
    });
  }

  @override
  Future<void> createChat(List<String> participants) async {
    participants.sort();
    final chatId = participants.join('_');
    
    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSeenBy': { for (var p in participants) p : true },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    final batch = _firestore.batch();
    
    // 1. Add message
    final msgRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderUid': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSeenBy': { senderId: true }, // The sender has seen it, others have not
    });

    await batch.commit();
  }
}
