// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String,
  senderId: json['senderId'] as String,
  type: $enumDecode(_$MessageTypeEnumMap, json['type']),
  content: json['content'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  serverTimestamp: json['serverTimestamp'] == null
      ? null
      : DateTime.parse(json['serverTimestamp'] as String),
  status: $enumDecode(
    _$MessageStatusEnumMap,
    json['status'],
    unknownValue: MessageStatus.sent,
  ),
  uploadPending: json['uploadPending'] as bool? ?? false,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  mediaWidth: (json['mediaWidth'] as num?)?.toInt(),
  mediaHeight: (json['mediaHeight'] as num?)?.toInt(),
  durationMs: (json['durationMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'conversationId': instance.conversationId,
  'senderId': instance.senderId,
  'type': _$MessageTypeEnumMap[instance.type]!,
  'content': instance.content,
  'timestamp': instance.timestamp.toIso8601String(),
  'serverTimestamp': instance.serverTimestamp?.toIso8601String(),
  'status': _$MessageStatusEnumMap[instance.status]!,
  'uploadPending': instance.uploadPending,
  'thumbnailUrl': instance.thumbnailUrl,
  'mediaWidth': instance.mediaWidth,
  'mediaHeight': instance.mediaHeight,
  'durationMs': instance.durationMs,
};

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.voice: 'voice',
  MessageType.video: 'video',
};

const _$MessageStatusEnumMap = {
  MessageStatus.sending: 'sending',
  MessageStatus.sent: 'sent',
  MessageStatus.delivered: 'delivered',
  MessageStatus.read: 'read',
  MessageStatus.failed: 'failed',
};
