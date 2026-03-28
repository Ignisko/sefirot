import 'package:cloud_firestore/cloud_firestore.dart';

// Sentinel value used by copyWith to distinguish "not provided" from explicit null.
const _unset = _Unset();

final class _Unset {
  const _Unset();
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String accountType; // Defaulting all users to 'pilgrim'

  final String bio;
  final List<String> interests;
  final List<String> languages;
  final List<String> events;
  final DateTime? createdAt; // Can be null locally until fetched from Firestore
  final String nationality;
  final bool isOnboarded;
  final List<String> blockedUids;
  final String diocese;
  final String city;
  final double? lat;
  final double? lng;
  final int? age;
  final int? targetMinAge;
  final int? targetMaxAge;
  final bool isAdmin;
  final bool isBanned;
  final String gender; // 'Male' | 'Female' | 'Other' | ''

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
    this.blockedUids = const [],
    this.diocese = '',
    this.city = '',
    this.lat,
    this.lng,
    this.age,
    this.targetMinAge = 18,
    this.targetMaxAge = 100,
    this.isAdmin = false,
    this.isBanned = false,
    this.gender = '',
  });

  // Convert UserModel to a Map (useful for Firestore)
  Map<String, dynamic> toMap({bool includeAdminFields = false}) {
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
      'blockedUids': blockedUids,
      'diocese': diocese,
      'city': city,
      'lat': lat != null ? double.parse(lat!.toStringAsFixed(3)) : null,
      'lng': lng != null ? double.parse(lng!.toStringAsFixed(3)) : null,
      'age': age,
      'targetMinAge': targetMinAge,
      'targetMaxAge': targetMaxAge,
      'gender': gender,
    };


    // We EXCLUDE isAdmin and isBanned from the map sent to Firestore 
    // to prevent any accidental self-elevation or exposure of these fields.
    // They are managed via a separate private collection for V2.0 security.
    
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
      blockedUids: List<String>.from(map['blockedUids'] ?? []),
      diocese: map['diocese'] ?? '',
      city: map['city'] ?? '',
      lat: double.tryParse(map['lat']?.toString() ?? ''),
      lng: double.tryParse(map['lng']?.toString() ?? ''),
      age: int.tryParse(map['age']?.toString() ?? ''),
      targetMinAge: int.tryParse(map['targetMinAge']?.toString() ?? '18') ?? 18,
      targetMaxAge: int.tryParse(map['targetMaxAge']?.toString() ?? '100') ?? 100,
      isAdmin: map['isAdmin'] ?? false,
      isBanned: map['isBanned'] ?? false,
      gender: map['gender'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
    );
  }

  // Helper method to create a copy of the model with updated fields.
  // Pass null explicitly for [lat], [lng], or [age] to clear those fields.
  // For non-nullable fields, omit the parameter to keep the existing value.
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
    List<String>? blockedUids,
    String? diocese,
    String? city,
    Object? lat = _unset,   // use null to clear
    Object? lng = _unset,   // use null to clear
    Object? age = _unset,   // use null to clear
    int? targetMinAge,
    int? targetMaxAge,
    bool? isAdmin,
    bool? isBanned,
    String? gender,
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
      blockedUids: blockedUids ?? this.blockedUids,
      diocese: diocese ?? this.diocese,
      city: city ?? this.city,
      lat: lat == _unset ? this.lat : lat as double?,
      lng: lng == _unset ? this.lng : lng as double?,
      age: age == _unset ? this.age : age as int?,
      targetMinAge: targetMinAge ?? this.targetMinAge,
      targetMaxAge: targetMaxAge ?? this.targetMaxAge,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      gender: gender ?? this.gender,
    );
  }
}
