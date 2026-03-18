import 'package:semya/domain/entities/conversation.dart';

abstract class ConversationRepository {
  Future<void> createConversation(Conversation conversation);
  Future<Conversation?> getConversation(String id);
  Stream<Conversation?> watchConversation(String id);
  Stream<List<Conversation>> getUserConversations(String userId);
  Future<void> updateConversation(Conversation conversation);
  Future<Conversation?> findDirectConversation(String userId1, String userId2);
  Future<void> markConversationDelivered(String conversationId, String userId);
  Future<void> markConversationRead(String conversationId, String userId);
}
