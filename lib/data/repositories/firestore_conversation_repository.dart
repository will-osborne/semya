import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/domain/repositories/conversation_repository.dart';

class FirestoreConversationRepository implements ConversationRepository {
  FirestoreConversationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'conversations';

  CollectionReference<Map<String, dynamic>> get _conversationsCollection =>
      _firestore.collection(_collection);

  @override
  Future<void> createConversation(Conversation conversation) async {
    await _conversationsCollection
        .doc(conversation.id)
        .set(conversation.toJson());
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final doc = await _conversationsCollection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Conversation.fromJson(_withId(doc.id, doc.data()!));
  }

  @override
  Stream<Conversation?> watchConversation(String id) {
    return _conversationsCollection.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return Conversation.fromJson(_withId(doc.id, data));
    });
  }

  @override
  Stream<List<Conversation>> getUserConversations(String userId) {
    return _conversationsCollection
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Conversation.fromJson(_withId(doc.id, doc.data())))
              .toList(),
        );
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    await _conversationsCollection
        .doc(conversation.id)
        .update(conversation.toJson());
  }

  @override
  Future<Conversation?> findDirectConversation(
    String userId1,
    String userId2,
  ) async {
    // Query for direct conversations where userId1 is a participant, then
    // filter client-side for userId2 because Firestore does not support
    // two separate arrayContains clauses on the same field in a single query.
    final snapshot = await _conversationsCollection
        .where('type', isEqualTo: ConversationType.direct.name)
        .where('participantIds', arrayContains: userId1)
        .get();

    final matching = snapshot.docs.where((doc) {
      final data = doc.data();
      final participants = List<String>.from(
        (data['participantIds'] as List?) ?? [],
      );
      return participants.contains(userId2);
    }).toList();

    if (matching.isEmpty) return null;

    final doc = matching.first;
    return Conversation.fromJson(_withId(doc.id, doc.data()));
  }

  @override
  Future<void> markConversationDelivered(
    String conversationId,
    String userId,
  ) async {
    await _conversationsCollection.doc(conversationId).update({
      'lastDeliveredAtByUser.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markConversationRead(
    String conversationId,
    String userId,
  ) async {
    await _conversationsCollection.doc(conversationId).update({
      'unreadCounts.$userId': 0,
      'lastDeliveredAtByUser.$userId': FieldValue.serverTimestamp(),
      'lastReadAtByUser.$userId': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _withId(String id, Map<String, dynamic> data) {
    final copy = {...data, 'id': id};
    // Firestore returns Timestamp objects but the generated fromJson expects
    // ISO-8601 strings.
    for (final key in const ['createdAt', 'lastMessageAt']) {
      final normalizedValue = _normalizeDateTimeValue(copy[key]);
      if (normalizedValue != null) {
        copy[key] = normalizedValue;
      }
    }
    for (final key in const ['lastDeliveredAtByUser', 'lastReadAtByUser']) {
      final value = copy[key];
      if (value is Map) {
        final normalizedMap = <String, String>{};
        value.forEach((mapKey, mapValue) {
          final normalizedValue = _normalizeDateTimeValue(mapValue);
          if (normalizedValue == null) return;
          normalizedMap[mapKey.toString()] = normalizedValue;
        });
        copy[key] = normalizedMap;
      }
    }
    return copy;
  }

  String? _normalizeDateTimeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }
}
