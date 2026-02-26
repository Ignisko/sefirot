import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/matchmaking_repository.dart';
import '../../data/repositories/firebase_matchmaking_repository.dart';
import '../../domain/models/match_preference_model.dart';
import '../../domain/models/connection_model.dart';
import 'auth_provider.dart';

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>((ref) {
  return FirebaseMatchmakingRepository();
});

final currentMatchPreferenceProvider = StreamProvider<MatchPreferenceModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        final repo = ref.watch(matchmakingRepositoryProvider);
        return repo.getMatchPreference(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});

final pendingConnectionsProvider = StreamProvider<List<ConnectionModel>>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        final repo = ref.watch(matchmakingRepositoryProvider);
        return repo.getPendingConnections(user.uid);
      }
      return Stream.value([]);
    },
    loading: () => Stream.value([]),
    error: (error, stackTrace) => Stream.value([]),
  );
});
