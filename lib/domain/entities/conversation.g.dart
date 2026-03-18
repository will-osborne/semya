// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      type: $enumDecode(_$ConversationTypeEnumMap, json['type']),
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      lastMessagePreview: json['lastMessagePreview'] as String?,
      unreadCounts:
          (json['unreadCounts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      lastDeliveredAtByUser:
          (json['lastDeliveredAtByUser'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, DateTime.parse(e as String)),
          ) ??
          const <String, DateTime>{},
      lastReadAtByUser:
          (json['lastReadAtByUser'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, DateTime.parse(e as String)),
          ) ??
          const <String, DateTime>{},
      createdBy: json['createdBy'] as String,
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConversationTypeEnumMap[instance.type]!,
      'participantIds': instance.participantIds,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'lastMessagePreview': instance.lastMessagePreview,
      'unreadCounts': instance.unreadCounts,
      'lastDeliveredAtByUser': instance.lastDeliveredAtByUser.map(
        (k, e) => MapEntry(k, e.toIso8601String()),
      ),
      'lastReadAtByUser': instance.lastReadAtByUser.map(
        (k, e) => MapEntry(k, e.toIso8601String()),
      ),
      'createdBy': instance.createdBy,
    };

const _$ConversationTypeEnumMap = {
  ConversationType.direct: 'direct',
  ConversationType.group: 'group',
};
