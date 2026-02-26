import '../models/match_preference_model.dart';
import '../models/connection_model.dart';

abstract class MatchmakingRepository {
  /// Match Preferences
  Stream<MatchPreferenceModel?> getMatchPreference(String uid);
  Future<void> updateMatchPreference(MatchPreferenceModel preference);

  /// Connections & Swiping
  /// Creates a connection or updates it if one side already swiped
  Future<void> createOrUpdateConnection({
    required String senderId,
    required String receiverId,
    required ConnectionStatus status,
  });

  /// Listen to pending connections (people who swiped right on the current user)
  Stream<List<ConnectionModel>> getPendingConnections(String uid);

  /// Chats
  Future<void> createChat(List<String> participants);
  Future<void> sendMessage(String chatId, String senderId, String text);
}
