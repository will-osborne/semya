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
}
