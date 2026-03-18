import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

enum ConversationType { direct, group }

@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required ConversationType type,
    required List<String> participantIds,
    String? title,
    required DateTime createdAt,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    @Default(<String, int>{}) Map<String, int> unreadCounts,
    @Default(<String, DateTime>{}) Map<String, DateTime> lastDeliveredAtByUser,
    @Default(<String, DateTime>{}) Map<String, DateTime> lastReadAtByUser,
    required String createdBy,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}
