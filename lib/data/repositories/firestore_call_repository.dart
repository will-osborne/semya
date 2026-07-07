import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:semya/domain/entities/call.dart';
import 'package:semya/domain/repositories/call_repository.dart';

class FirestoreCallRepository implements CallRepository {
  FirestoreCallRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'calls';
  static const String _candidatesSubcollection = 'candidates';

  // Ringing calls older than this are considered stale (crash/network
  // leftovers) and never surfaced as incoming.
  static const _staleRingThreshold = Duration(seconds: 60);

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection(_collection);

  @override
  Future<void> createCall(Call call) async {
    final data = call.toJson();
    data.remove('id');
    // Use server timestamp for ordering.
    data['createdAt'] = FieldValue.serverTimestamp();
    await _callsCollection.doc(call.id).set(data);
  }

  @override
  Future<Call?> getCall(String callId) async {
    final doc = await _callsCollection.doc(callId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Call.fromJson(_withId(doc.id, doc.data()!));
  }

  @override
  Stream<Call?> watchCall(String callId) {
    return _callsCollection.doc(callId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Call.fromJson(_withId(doc.id, doc.data()!));
    });
  }

  @override
  Future<void> updateCall(String callId, Map<String, dynamic> data) async {
    await _callsCollection.doc(callId).update(data);
  }

  @override
  Future<void> setOffer(String callId, Map<String, dynamic> offer) async {
    await _callsCollection.doc(callId).update({'offer': offer});
  }

  @override
  Future<void> setAnswer(String callId, Map<String, dynamic> answer) async {
    await _callsCollection.doc(callId).update({'answer': answer});
  }

  @override
  Future<void> addIceCandidate(String callId, IceCandidate candidate) async {
    final data = candidate.toJson();
    data.remove('id');
    // Use a client-side timestamp so the document is immediately visible to
    // queries. FieldValue.serverTimestamp() causes documents to be excluded
    // from query results while the write is pending (50–500ms), which makes
    // ICE candidates invisible to the remote peer during that window.
    data['createdAt'] = Timestamp.now();
    await _callsCollection
        .doc(callId)
        .collection(_candidatesSubcollection)
        .doc(candidate.id)
        .set(data);
  }

  @override
  Stream<List<IceCandidate>> watchIceCandidates(
    String callId,
    String fromUserId,
  ) {
    // No orderBy — WebRTC handles candidates in any order, and ordering by a
    // server timestamp would exclude pending-write documents from snapshots.
    return _callsCollection
        .doc(callId)
        .collection(_candidatesSubcollection)
        .where('fromUserId', isEqualTo: fromUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return IceCandidate.fromJson(_withId(doc.id, doc.data()));
          }).toList(),
        );
  }

  @override
  Stream<Call?> watchIncomingCalls(String userId) {
    // Only consider calls created within the last 60 seconds to avoid
    // showing stale ringing calls caused by crashes or network errors.
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(_staleRingThreshold),
    );

    return _callsCollection
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          final call = Call.fromJson(_withId(doc.id, doc.data()));
          // The query cutoff above is computed once, at subscription time,
          // and this stream lives for the whole session — so on its own the
          // filter decays to "created since app start". Re-check staleness
          // against the current clock on every emit.
          final expiry = DateTime.now().subtract(_staleRingThreshold);
          if (call.createdAt.isBefore(expiry)) return null;
          return call;
        });
  }

  @override
  Future<Call?> getRingingCallBetween({
    required String callerId,
    required String calleeId,
  }) async {
    // Reuses the existing (calleeId, status, createdAt) composite index from
    // watchIncomingCalls; callerId is filtered client-side to avoid needing
    // another composite index for what is at most a handful of documents.
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(_staleRingThreshold),
    );

    final snapshot = await _callsCollection
        .where('calleeId', isEqualTo: calleeId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .get();

    for (final doc in snapshot.docs) {
      final call = Call.fromJson(_withId(doc.id, doc.data()));
      if (call.callerId == callerId) return call;
    }
    return null;
  }

  @override
  Future<void> initiateIceRestart(
    String callId,
    Map<String, dynamic> offer,
  ) async {
    // Write the new restart offer and clear any stale answer so the callee
    // knows this is a fresh restart request.
    await _callsCollection.doc(callId).update({
      'restartOffer': offer,
      'restartAnswer': FieldValue.delete(),
    });
  }

  @override
  Future<void> acknowledgeIceRestart(
    String callId,
    Map<String, dynamic> answer,
  ) async {
    await _callsCollection.doc(callId).update({'restartAnswer': answer});
  }

  Map<String, dynamic> _withId(String id, Map<String, dynamic> data) {
    final copy = {...data, 'id': id};
    for (final key in const ['createdAt', 'endedAt']) {
      final value = copy[key];
      if (value is Timestamp) {
        copy[key] = value.toDate().toIso8601String();
      }
    }
    return copy;
  }
}
