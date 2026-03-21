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

  /// Writes a new ICE restart offer from the caller and clears any previous
  /// restart answer. Only the original caller initiates ICE restarts.
  Future<void> initiateIceRestart(String callId, Map<String, dynamic> offer);

  /// Writes the callee's answer to a pending ICE restart offer.
  Future<void> acknowledgeIceRestart(String callId, Map<String, dynamic> answer);
}
