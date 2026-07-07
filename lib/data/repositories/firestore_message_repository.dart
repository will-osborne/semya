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

  DocumentReference<Map<String, dynamic>> _conversationRef(
    String conversationId,
  ) {
    return _firestore.collection(_conversationsCollection).doc(conversationId);
  }

  @override
  Future<void> sendMessage(
    Message message, {
    List<String>? participantIds,
  }) async {
    final recipients =
        participantIds ?? await _participantIdsFor(message.conversationId);

    final batch = _firestore.batch();
    batch.set(
      _messagesCollection(message.conversationId).doc(message.id),
      _messageJson(message),
    );
    batch.update(
      _conversationRef(message.conversationId),
      _conversationUpdatesFor(message, recipients),
    );

    // No timeout: a timed-out await would not cancel the queued write (that
    // was the phantom-delivery bug). This future completes when the server
    // acknowledges the batch and errors only on an actual rejection —
    // callers relying on Firestore's offline queue should not await it.
    await batch.commit();
  }

  @override
  Future<void> createMessage(Message message) async {
    await _messagesCollection(
      message.conversationId,
    ).doc(message.id).set(_messageJson(message));
  }

  @override
  Future<void> finalizeMessage(
    Message message, {
    List<String>? participantIds,
  }) async {
    final recipients =
        participantIds ?? await _participantIdsFor(message.conversationId);

    final batch = _firestore.batch();
    batch.update(_messagesCollection(message.conversationId).doc(message.id), {
      'content': message.content,
      'thumbnailUrl': message.thumbnailUrl,
      'mediaWidth': message.mediaWidth,
      'mediaHeight': message.mediaHeight,
      'uploadPending': false,
      'status': MessageStatus.sent.name,
    });
    batch.update(
      _conversationRef(message.conversationId),
      _conversationUpdatesFor(message, recipients),
    );
    await batch.commit();
  }

  @override
  Stream<List<Message>> getMessages(String conversationId, {int limit = 50}) {
    final query = _messagesCollection(
      conversationId,
    ).orderBy('serverTimestamp', descending: true).limit(limit);

    // Metadata changes are included so pending local writes (offline queue /
    // latency compensation) can be surfaced as "sending" in the UI.
    return query
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map(_messageFromDoc).toList());
  }

  @override
  Future<List<Message>> getMessagesBatch(
    String conversationId, {
    int limit = 20,
    String? beforeMessageId,
  }) async {
    Query<Map<String, dynamic>> query = _messagesCollection(
      conversationId,
    ).orderBy('serverTimestamp', descending: true);

    if (beforeMessageId != null) {
      // Cursor on the actual document: a bare timestamp cursor skips
      // messages that share an identical serverTimestamp.
      final anchor = await _messagesCollection(
        conversationId,
      ).doc(beforeMessageId).get();
      if (!anchor.exists) return const [];
      query = query.startAfterDocument(anchor);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map(_messageFromDoc).toList();
  }

  @override
  Future<void> updateMessageStatus(
    String conversationId,
    String messageId,
    MessageStatus status, {
    bool uploadPending = false,
  }) async {
    await _messagesCollection(conversationId).doc(messageId).update({
      'status': status.name,
      'uploadPending': uploadPending,
    });
  }

  Map<String, dynamic> _messageJson(Message message) {
    final json = message.toJson();
    // Use Firestore server timestamp for consistent ordering across devices.
    json['serverTimestamp'] = FieldValue.serverTimestamp();
    return json;
  }

  Message _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    var message = Message.fromJson(_withId(doc.id, doc.data() ?? const {}));
    final pending =
        doc.metadata.hasPendingWrites || message.serverTimestamp == null;
    if (!pending && message.status == MessageStatus.sending) {
      // Legacy docs persisted a transient 'sending' status; a doc the server
      // has acknowledged was sent regardless of what the old client wrote.
      message = message.copyWith(status: MessageStatus.sent);
    }
    return message.copyWith(isPending: pending);
  }

  /// Resolves participant ids with a cache-first read, falling back to the
  /// default (server-then-cache) read on a cache miss.
  Future<List<String>> _participantIdsFor(String conversationId) async {
    final ref = _conversationRef(conversationId);
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await ref.get(const GetOptions(source: Source.cache));
      if (!snapshot.exists) {
        snapshot = await ref.get();
      }
    } on FirebaseException {
      snapshot = await ref.get();
    }
    final data = snapshot.data();
    if (data == null) return const [];
    return List<String>.from(
      (data['participantIds'] as List?) ?? const <String>[],
    );
  }

  Map<String, Object?> _conversationUpdatesFor(
    Message message,
    List<String> participantIds,
  ) {
    final updates = <String, Object?>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': _previewFor(message),
      'unreadCounts.${message.senderId}': 0,
      'lastDeliveredAtByUser.${message.senderId}': FieldValue.serverTimestamp(),
      'lastReadAtByUser.${message.senderId}': FieldValue.serverTimestamp(),
    };
    for (final participantId in participantIds) {
      if (participantId == message.senderId) continue;
      updates['unreadCounts.$participantId'] = FieldValue.increment(1);
    }
    return updates;
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
