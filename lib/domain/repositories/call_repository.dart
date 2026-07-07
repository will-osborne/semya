import 'package:semya/domain/entities/call.dart';

abstract class CallRepository {
  Future<void> createCall(Call call);
  Future<Call?> getCall(String callId);
  Stream<Call?> watchCall(String callId);
  Future<void> updateCall(String callId, Map<String, dynamic> data);
  Future<void> setOffer(String callId, Map<String, dynamic> offer);
  Future<void> setAnswer(String callId, Map<String, dynamic> answer);
  Future<void> addIceCandidate(String callId, IceCandidate candidate);
  Stream<List<IceCandidate>> watchIceCandidates(
    String callId,
    String fromUserId,
  );
  Stream<Call?> watchIncomingCalls(String userId);

  /// Returns a fresh ringing call from [callerId] to [calleeId], if one
  /// exists. Used for glare handling: when both users dial each other at
  /// once, the initiator answers the existing call instead of creating a
  /// competing one.
  Future<Call?> getRingingCallBetween({
    required String callerId,
    required String calleeId,
  });

  /// Writes a new ICE restart offer from the caller and clears any previous
  /// restart answer. Only the original caller initiates ICE restarts.
  Future<void> initiateIceRestart(String callId, Map<String, dynamic> offer);

  /// Writes the callee's answer to a pending ICE restart offer.
  Future<void> acknowledgeIceRestart(String callId, Map<String, dynamic> answer);
}
