import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String phoneNumber,
    String? displayName,
    String? photoUrl,
    required DateTime createdAt,
    required List<String> deviceIds,
    @Default([]) List<String> fcmTokens,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
