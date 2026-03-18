// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IceCandidate _$IceCandidateFromJson(Map<String, dynamic> json) =>
    _IceCandidate(
      id: json['id'] as String,
      candidate: json['candidate'] as String,
      sdpMid: json['sdpMid'] as String,
      sdpMLineIndex: (json['sdpMLineIndex'] as num).toInt(),
      fromUserId: json['fromUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$IceCandidateToJson(_IceCandidate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'candidate': instance.candidate,
      'sdpMid': instance.sdpMid,
      'sdpMLineIndex': instance.sdpMLineIndex,
      'fromUserId': instance.fromUserId,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_Call _$CallFromJson(Map<String, dynamic> json) => _Call(
  id: json['id'] as String,
  callerId: json['callerId'] as String,
  calleeId: json['calleeId'] as String,
  participantIds: (json['participantIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  conversationId: json['conversationId'] as String,
  status: $enumDecode(_$CallStatusEnumMap, json['status']),
  offer: json['offer'] as Map<String, dynamic>?,
  answer: json['answer'] as Map<String, dynamic>?,
  callerVideoEnabled: json['callerVideoEnabled'] as bool? ?? false,
  calleeVideoEnabled: json['calleeVideoEnabled'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  endReason: $enumDecodeNullable(_$CallEndReasonEnumMap, json['endReason']),
);

Map<String, dynamic> _$CallToJson(_Call instance) => <String, dynamic>{
  'id': instance.id,
  'callerId': instance.callerId,
  'calleeId': instance.calleeId,
  'participantIds': instance.participantIds,
  'conversationId': instance.conversationId,
  'status': _$CallStatusEnumMap[instance.status]!,
  'offer': instance.offer,
  'answer': instance.answer,
  'callerVideoEnabled': instance.callerVideoEnabled,
  'calleeVideoEnabled': instance.calleeVideoEnabled,
  'createdAt': instance.createdAt.toIso8601String(),
  'endedAt': instance.endedAt?.toIso8601String(),
  'endReason': _$CallEndReasonEnumMap[instance.endReason],
};

const _$CallStatusEnumMap = {
  CallStatus.ringing: 'ringing',
  CallStatus.connected: 'connected',
  CallStatus.ended: 'ended',
  CallStatus.missed: 'missed',
  CallStatus.rejected: 'rejected',
};

const _$CallEndReasonEnumMap = {
  CallEndReason.hangUp: 'hangUp',
  CallEndReason.rejected: 'rejected',
  CallEndReason.timeout: 'timeout',
  CallEndReason.error: 'error',
};
