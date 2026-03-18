// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  phoneNumber: json['phoneNumber'] as String,
  displayName: json['displayName'] as String?,
  photoUrl: json['photoUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  deviceIds: (json['deviceIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  fcmTokens:
      (json['fcmTokens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'phoneNumber': instance.phoneNumber,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'deviceIds': instance.deviceIds,
  'fcmTokens': instance.fcmTokens,
};
