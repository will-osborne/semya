// @JsonKey on freezed constructor parameters is the documented freezed
// pattern; the analyzer flags it as it only sees a constructor parameter.
// ignore_for_file: invalid_annotation_target

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
    @JsonKey(unknownEnumValue: MessageStatus.sent)
    required MessageStatus status,

    /// True while media/voice content is still uploading. While set,
    /// [content] holds a local file path instead of a download URL.
    /// Persisted to Firestore so a retry bubble survives restarts.
    @Default(false) bool uploadPending,

    /// True while the local write has not been acknowledged by the server
    /// (derived from snapshot metadata / a missing server timestamp).
    /// Never persisted.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isPending,
    String? thumbnailUrl,
    int? mediaWidth,
    int? mediaHeight,

    /// Duration of voice-note audio in milliseconds, measured at send time.
    /// Null for non-voice messages and legacy voice notes (those fall back to
    /// a one-time Storage metadata fetch).
    int? durationMs,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
