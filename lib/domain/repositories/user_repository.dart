import '../models/user_model.dart';

abstract class UserRepository {
  Stream<UserModel?> getUser(String uid);
  Future<void> updateUser(UserModel user);
  
  // Reporting & Admin
  Future<void> reportUser(String reporterUid, String reportedUid, String reason);
  Future<void> dismissReport(String reportId);
  Future<void> banUser(String adminUid, String targetUid, String reportId);
}
