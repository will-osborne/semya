import 'package:semya/domain/entities/message.dart';

abstract class MessageRepository {
  /// Writes the message and the conversation preview/unread updates in one
  /// atomic batch. The returned future completes when the server acknowledges
  /// the batch and errors only on an actual rejection — callers relying on
  /// Firestore's offline queue should not await it for UI purposes.
  ///
  /// [participantIds] avoids a conversation read when the caller already has
  /// the conversation loaded; when omitted, a cache-first read is used.
  Future<void> sendMessage(Message message, {List<String>? participantIds});

  /// Creates the message document only — no conversation preview/unread
  /// update. Used for media/voice placeholders before the upload completes;
  /// [finalizeMessage] applies the conversation updates afterwards.
  Future<void> createMessage(Message message);

  /// Updates a placeholder message with its final content (download URL,
  /// thumbnail, dimensions) and applies the conversation preview/unread
  /// updates in one atomic batch.
  Future<void> finalizeMessage(Message message, {List<String>? participantIds});

  /// Real-time message stream (newest first) including pending local writes.
  /// Emitted messages carry [Message.isPending] derived from snapshot
  /// metadata.
  Stream<List<Message>> getMessages(String conversationId, {int limit = 50});

  /// One-time fetch of messages older than [beforeMessageId] for pagination.
  Future<List<Message>> getMessagesBatch(
    String conversationId, {
    int limit = 20,
    String? beforeMessageId,
  });

  Future<void> updateMessageStatus(
    String conversationId,
    String messageId,
    MessageStatus status, {
    bool uploadPending = false,
  });
}
