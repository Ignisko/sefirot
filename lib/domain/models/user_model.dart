import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String accountType; // e.g. 'pilgrim', 'volunteer'
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final List<String> events;
  final DateTime? createdAt; // Can be null locally until fetched from Firestore
  final String nationality;
  final bool isOnboarded;
  final bool isAdmin;
  final bool isBanned;
  final List<String> blockedUids;
  final String diocese;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.accountType,
    required this.bio,
    required this.interests,
    required this.languages,
    required this.events,
    this.createdAt,
    this.nationality = '',
    this.isOnboarded = false,
    this.isAdmin = false,
    this.isBanned = false,
    this.blockedUids = const [],
    this.diocese = '',
  });

  // Convert UserModel to a Map (useful for Firestore)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'accountType': accountType,
      'bio': bio,
      'interests': interests,
      'languages': languages,
      'events': events,
      'nationality': nationality,
      'isOnboarded': isOnboarded,
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      'blockedUids': blockedUids,
      'diocese': diocese,
    };
    if (createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt!);
    }
    return map;
  }

  // Create a UserModel from a Map (Firestore document snapshot)
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId, // Or map['uid'] but documentId is usually safer
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      accountType: map['accountType'] ?? 'pilgrim',
      bio: map['bio'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      languages: List<String>.from(map['languages'] ?? []),
      events: List<String>.from(map['events'] ?? []),
      nationality: map['nationality'] ?? '',
      isOnboarded: map['isOnboarded'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isBanned: map['isBanned'] ?? false,
      blockedUids: List<String>.from(map['blockedUids'] ?? []),
      diocese: map['diocese'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
    );
  }

  // Helper method to create a copy of the model with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? accountType,
    String? bio,
    List<String>? interests,
    List<String>? languages,
    List<String>? events,
    DateTime? createdAt,
    String? nationality,
    bool? isOnboarded,
    bool? isAdmin,
    bool? isBanned,
    List<String>? blockedUids,
    String? diocese,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      accountType: accountType ?? this.accountType,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      events: events ?? this.events,
      createdAt: createdAt ?? this.createdAt,
      nationality: nationality ?? this.nationality,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      blockedUids: blockedUids ?? this.blockedUids,
      diocese: diocese ?? this.diocese,
    );
  }
}
