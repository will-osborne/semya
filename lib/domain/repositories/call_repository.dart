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

  /// Writes a restart offer (created with iceRestart=true) to the call doc.
  /// The remote peer watches for this and responds with a restart answer.
  Future<void> setRestartOffer(String callId, Map<String, dynamic> offer);

  /// Writes a restart answer in response to a restart offer.
  Future<void> setRestartAnswer(String callId, Map<String, dynamic> answer);

  /// Emits `{offer, answer?}` maps as the restart negotiation fields change.
  /// Emits null when neither field is present.
  Stream<Map<String, dynamic>?> watchRestartNegotiation(String callId);
}
