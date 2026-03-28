import 'package:cloud_firestore/cloud_firestore.dart';

class MatchPreferenceModel {
  final String userId;
  final String seekingRole; // e.g. 'pilgrim' or 'any'

  final int minAge;
  final int maxAge;
  final List<String> preferredLanguages;
  final bool discoverable;
  final DateTime updatedAt;

  MatchPreferenceModel({
    required this.userId,
    this.seekingRole = 'any',
    this.minAge = 18,
    this.maxAge = 100,
    this.preferredLanguages = const [],
    this.discoverable = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'seekingRole': seekingRole,
      'minAge': minAge,
      'maxAge': maxAge,
      'preferredLanguages': preferredLanguages,
      'discoverable': discoverable,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MatchPreferenceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchPreferenceModel(
      userId: documentId,
      seekingRole: map['seekingRole'] ?? 'any',
      minAge: map['minAge']?.toInt() ?? 18,
      maxAge: map['maxAge']?.toInt() ?? 100,
      preferredLanguages: List<String>.from(map['preferredLanguages'] ?? []),
      discoverable: map['discoverable'] ?? true,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  MatchPreferenceModel copyWith({
    String? seekingRole,
    int? minAge,
    int? maxAge,
    List<String>? preferredLanguages,
    bool? discoverable,
  }) {
    return MatchPreferenceModel(
      userId: userId,
      seekingRole: seekingRole ?? this.seekingRole,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      discoverable: discoverable ?? this.discoverable,
      updatedAt: DateTime.now(),
    );
  }
}
