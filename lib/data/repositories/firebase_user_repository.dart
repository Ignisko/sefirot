import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirebaseUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> getUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(user.toMap());
  }

  @override
  Future<void> reportUser(String reporterUid, String reportedUid, String reason) async {
    await _firestore.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<void> dismissReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({'status': 'dismissed'});
  }

  @override
  Future<void> banUser(String adminUid, String targetUid, String reportId) async {
    final batch = _firestore.batch();
    
    // 1. Ban the user
    final userRef = _firestore.collection('users').doc(targetUid);
    batch.update(userRef, {'isBanned': true});
    
    // 2. Mark report as resolved if provided
    if (reportId.isNotEmpty) {
      final reportRef = _firestore.collection('reports').doc(reportId);
      batch.update(reportRef, {'status': 'resolved'});
    }
    
    await batch.commit();
  }
}
