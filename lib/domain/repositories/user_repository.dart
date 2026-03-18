import 'package:semya/domain/entities/user.dart';

abstract class UserRepository {
  Future<void> createUser(AppUser user);
  Future<AppUser?> getUser(String userId);
  Future<void> updateUser(AppUser user);
  Future<List<AppUser>> searchUsersByPhone(String phoneNumber);
  Future<void> addFcmToken(String userId, String token);
  Future<void> removeFcmToken(String userId, String token);
  Future<void> setVoipToken(String userId, String? token);
}
