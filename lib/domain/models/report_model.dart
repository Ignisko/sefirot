import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterUid;
  final String reportedUid;
  final String reason;
  final DateTime? timestamp;
  final String status;

  ReportModel({
    required this.id,
    required this.reporterUid,
    required this.reportedUid,
    required this.reason,
    this.timestamp,
    required this.status,
  });

  factory ReportModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ReportModel(
      id: documentId,
      reporterUid: data['reporterUid'] ?? '',
      reportedUid: data['reportedUid'] ?? '',
      reason: data['reason'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}
