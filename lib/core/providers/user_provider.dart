import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/firebase_user_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirebaseUserRepository();
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  
  return authState.when(
    data: (user) {
      if (user != null) {
        final userRepository = ref.watch(userRepositoryProvider);
        return userRepository.getUser(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});

final userProfileProvider = StreamProvider.family.autoDispose<UserModel?, String>((ref, uid) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUser(uid);
});

/// Dedicated provider to check if a user has administrative privileges.
/// This checks a restricted 'admins' collection for the user's UID.
final isAdminProvider = StreamProvider.family.autoDispose<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists);
});

