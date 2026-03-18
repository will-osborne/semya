import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageType { text, image, voice, video }

enum MessageStatus { sending, sent, delivered, read, failed }

@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required String conversationId,
    required String senderId,
    required MessageType type,
    required String content,
    required DateTime timestamp,
    DateTime? serverTimestamp,
    required MessageStatus status,
    String? thumbnailUrl,
    int? mediaWidth,
    int? mediaHeight,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
