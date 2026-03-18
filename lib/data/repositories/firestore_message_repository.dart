import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:semya/domain/entities/message.dart';
import 'package:semya/domain/repositories/message_repository.dart';

class FirestoreMessageRepository implements MessageRepository {
  FirestoreMessageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _conversationsCollection = 'conversations';
  static const String _messagesSubcollection = 'messages';

  CollectionReference<Map<String, dynamic>> _messagesCollection(
    String conversationId,
  ) {
    return _firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesSubcollection);
  }

  @override
  Future<void> sendMessage(Message message) async {
    final conversationRef = _firestore
        .collection(_conversationsCollection)
        .doc(message.conversationId);
    final conversationSnapshot = await conversationRef.get();
    final conversationData = conversationSnapshot.data();
    if (!conversationSnapshot.exists || conversationData == null) {
      throw StateError(
        'Conversation ${message.conversationId} does not exist.',
      );
    }

    final participantIds = List<String>.from(
      (conversationData['participantIds'] as List?) ?? const <String>[],
    );
    final batch = _firestore.batch();

    final messageRef = _messagesCollection(
      message.conversationId,
    ).doc(message.id);
    final json = message.toJson();
    // Use Firestore server timestamp for consistent ordering across devices.
    json['serverTimestamp'] = FieldValue.serverTimestamp();
    batch.set(messageRef, json);

    final preview = _previewFor(message);
    final conversationUpdates = <String, Object?>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': preview,
      'unreadCounts.${message.senderId}': 0,
      'lastDeliveredAtByUser.${message.senderId}': FieldValue.serverTimestamp(),
      'lastReadAtByUser.${message.senderId}': FieldValue.serverTimestamp(),
    };
    for (final participantId in participantIds) {
      if (participantId == message.senderId) continue;
      conversationUpdates['unreadCounts.$participantId'] = FieldValue.increment(
        1,
      );
    }
    batch.update(conversationRef, conversationUpdates);

    await batch.commit();
  }

  @override
  Stream<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) {
    Query<Map<String, dynamic>> query = _messagesCollection(
      conversationId,
    ).orderBy('serverTimestamp', descending: true).limit(limit);

    if (before != null) {
      query = query.startAfter([Timestamp.fromDate(before)]);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Message.fromJson(_withId(doc.id, doc.data())))
          .toList(),
    );
  }

  @override
  Future<List<Message>> getMessagesBatch(
    String conversationId, {
    int limit = 20,
    DateTime? before,
  }) async {
    Query<Map<String, dynamic>> query = _messagesCollection(
      conversationId,
    ).orderBy('serverTimestamp', descending: true).limit(limit);

    if (before != null) {
      query = query.startAfter([Timestamp.fromDate(before)]);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Message.fromJson(_withId(doc.id, doc.data())))
        .toList();
  }

  @override
  Future<Message?> getMessage(String id) async {
    // A message ID alone is not sufficient to locate the document because
    // messages live in a conversation subcollection. A collection group query
    // is used here so callers do not need to supply the conversationId.
    final snapshot = await _firestore
        .collectionGroup(_messagesSubcollection)
        .where(FieldPath.documentId, isEqualTo: id)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return Message.fromJson(_withId(doc.id, doc.data()));
  }

  @override
  Future<void> updateMessageStatus(
    String conversationId,
    String messageId,
    MessageStatus status,
  ) async {
    await _messagesCollection(
      conversationId,
    ).doc(messageId).update({'status': status.name});
  }

  Map<String, dynamic> _withId(String id, Map<String, dynamic> data) {
    final copy = {...data, 'id': id};
    // Firestore returns Timestamp objects but the generated fromJson expects
    // ISO-8601 strings.
    for (final key in const ['timestamp', 'serverTimestamp']) {
      final value = copy[key];
      if (value is Timestamp) {
        copy[key] = value.toDate().toIso8601String();
      }
    }
    return copy;
  }

  String _previewFor(Message message) {
    switch (message.type) {
      case MessageType.voice:
        return 'Voice message';
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.text:
        return message.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
}
