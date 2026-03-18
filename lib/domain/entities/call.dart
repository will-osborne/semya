import 'package:freezed_annotation/freezed_annotation.dart';

part 'call.freezed.dart';
part 'call.g.dart';

enum CallStatus { ringing, connected, ended, missed, rejected }

enum CallEndReason { hangUp, rejected, timeout, error }

@freezed
abstract class IceCandidate with _$IceCandidate {
  const factory IceCandidate({
    required String id,
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
    required String fromUserId,
    required DateTime createdAt,
  }) = _IceCandidate;

  factory IceCandidate.fromJson(Map<String, dynamic> json) =>
      _$IceCandidateFromJson(json);
}

@freezed
abstract class Call with _$Call {
  const factory Call({
    required String id,
    required String callerId,
    required String calleeId,
    required List<String> participantIds,
    required String conversationId,
    required CallStatus status,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
    @Default(false) bool callerVideoEnabled,
    @Default(false) bool calleeVideoEnabled,
    required DateTime createdAt,
    DateTime? endedAt,
    CallEndReason? endReason,
  }) = _Call;

  factory Call.fromJson(Map<String, dynamic> json) => _$CallFromJson(json);
}
