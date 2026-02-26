import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/report_model.dart';


final pendingReportsProvider = StreamProvider.autoDispose<List<ReportModel>>((ref) {
  // Only admins should ideally listen to this, but we'll secure via Security Rules or UI locks.
  return FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'pending')
      .orderBy('timestamp', descending: false) // oldest first
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ReportModel.fromMap(doc.data(), doc.id)).toList();
  });
});
