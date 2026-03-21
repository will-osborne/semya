import 'package:semya/domain/entities/message.dart';

abstract class MessageRepository {
  Future<void> sendMessage(Message message);
  Stream<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  });

  /// One-time fetch of messages for pagination (older messages).
  Future<List<Message>> getMessagesBatch(
    String conversationId, {
    int limit = 20,
    DateTime? before,
  });

  Future<Message?> getMessage(String id);
  Future<void> updateMessageStatus(
    String conversationId,
    String messageId,
    MessageStatus status,
  );

  /// Finds any messages in [conversationId] sent by [senderId] that are still
  /// in the [MessageStatus.sending] state and marks them [MessageStatus.failed].
  /// Called on chat open to recover messages stuck from a previous session.
  Future<void> markStuckSendingMessagesFailed(
    String conversationId,
    String senderId,
  );
}
