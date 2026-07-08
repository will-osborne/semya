// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message {

 String get id; String get conversationId; String get senderId; MessageType get type; String get content; DateTime get timestamp; DateTime? get serverTimestamp;@JsonKey(unknownEnumValue: MessageStatus.sent) MessageStatus get status;/// True while media/voice content is still uploading. While set,
/// [content] holds a local file path instead of a download URL.
/// Persisted to Firestore so a retry bubble survives restarts.
 bool get uploadPending;/// True while the local write has not been acknowledged by the server
/// (derived from snapshot metadata / a missing server timestamp).
/// Never persisted.
@JsonKey(includeFromJson: false, includeToJson: false) bool get isPending; String? get thumbnailUrl; int? get mediaWidth; int? get mediaHeight;/// Duration of voice-note audio in milliseconds, measured at send time.
/// Null for non-voice messages and legacy voice notes (those fall back to
/// a one-time Storage metadata fetch).
 int? get durationMs;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.type, type) || other.type == type)&&(identical(other.content, content) || other.content == content)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.serverTimestamp, serverTimestamp) || other.serverTimestamp == serverTimestamp)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadPending, uploadPending) || other.uploadPending == uploadPending)&&(identical(other.isPending, isPending) || other.isPending == isPending)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.mediaWidth, mediaWidth) || other.mediaWidth == mediaWidth)&&(identical(other.mediaHeight, mediaHeight) || other.mediaHeight == mediaHeight)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,type,content,timestamp,serverTimestamp,status,uploadPending,isPending,thumbnailUrl,mediaWidth,mediaHeight,durationMs);

@override
String toString() {
  return 'Message(id: $id, conversationId: $conversationId, senderId: $senderId, type: $type, content: $content, timestamp: $timestamp, serverTimestamp: $serverTimestamp, status: $status, uploadPending: $uploadPending, isPending: $isPending, thumbnailUrl: $thumbnailUrl, mediaWidth: $mediaWidth, mediaHeight: $mediaHeight, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id, String conversationId, String senderId, MessageType type, String content, DateTime timestamp, DateTime? serverTimestamp,@JsonKey(unknownEnumValue: MessageStatus.sent) MessageStatus status, bool uploadPending,@JsonKey(includeFromJson: false, includeToJson: false) bool isPending, String? thumbnailUrl, int? mediaWidth, int? mediaHeight, int? durationMs
});




}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? type = null,Object? content = null,Object? timestamp = null,Object? serverTimestamp = freezed,Object? status = null,Object? uploadPending = null,Object? isPending = null,Object? thumbnailUrl = freezed,Object? mediaWidth = freezed,Object? mediaHeight = freezed,Object? durationMs = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessageType,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,serverTimestamp: freezed == serverTimestamp ? _self.serverTimestamp : serverTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,uploadPending: null == uploadPending ? _self.uploadPending : uploadPending // ignore: cast_nullable_to_non_nullable
as bool,isPending: null == isPending ? _self.isPending : isPending // ignore: cast_nullable_to_non_nullable
as bool,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaWidth: freezed == mediaWidth ? _self.mediaWidth : mediaWidth // ignore: cast_nullable_to_non_nullable
as int?,mediaHeight: freezed == mediaHeight ? _self.mediaHeight : mediaHeight // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Message value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Message value)  $default,){
final _that = this;
switch (_that) {
case _Message():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Message value)?  $default,){
final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String conversationId,  String senderId,  MessageType type,  String content,  DateTime timestamp,  DateTime? serverTimestamp, @JsonKey(unknownEnumValue: MessageStatus.sent)  MessageStatus status,  bool uploadPending, @JsonKey(includeFromJson: false, includeToJson: false)  bool isPending,  String? thumbnailUrl,  int? mediaWidth,  int? mediaHeight,  int? durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.type,_that.content,_that.timestamp,_that.serverTimestamp,_that.status,_that.uploadPending,_that.isPending,_that.thumbnailUrl,_that.mediaWidth,_that.mediaHeight,_that.durationMs);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String conversationId,  String senderId,  MessageType type,  String content,  DateTime timestamp,  DateTime? serverTimestamp, @JsonKey(unknownEnumValue: MessageStatus.sent)  MessageStatus status,  bool uploadPending, @JsonKey(includeFromJson: false, includeToJson: false)  bool isPending,  String? thumbnailUrl,  int? mediaWidth,  int? mediaHeight,  int? durationMs)  $default,) {final _that = this;
switch (_that) {
case _Message():
return $default(_that.id,_that.conversationId,_that.senderId,_that.type,_that.content,_that.timestamp,_that.serverTimestamp,_that.status,_that.uploadPending,_that.isPending,_that.thumbnailUrl,_that.mediaWidth,_that.mediaHeight,_that.durationMs);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String conversationId,  String senderId,  MessageType type,  String content,  DateTime timestamp,  DateTime? serverTimestamp, @JsonKey(unknownEnumValue: MessageStatus.sent)  MessageStatus status,  bool uploadPending, @JsonKey(includeFromJson: false, includeToJson: false)  bool isPending,  String? thumbnailUrl,  int? mediaWidth,  int? mediaHeight,  int? durationMs)?  $default,) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.type,_that.content,_that.timestamp,_that.serverTimestamp,_that.status,_that.uploadPending,_that.isPending,_that.thumbnailUrl,_that.mediaWidth,_that.mediaHeight,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Message implements Message {
  const _Message({required this.id, required this.conversationId, required this.senderId, required this.type, required this.content, required this.timestamp, this.serverTimestamp, @JsonKey(unknownEnumValue: MessageStatus.sent) required this.status, this.uploadPending = false, @JsonKey(includeFromJson: false, includeToJson: false) this.isPending = false, this.thumbnailUrl, this.mediaWidth, this.mediaHeight, this.durationMs});
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String id;
@override final  String conversationId;
@override final  String senderId;
@override final  MessageType type;
@override final  String content;
@override final  DateTime timestamp;
@override final  DateTime? serverTimestamp;
@override@JsonKey(unknownEnumValue: MessageStatus.sent) final  MessageStatus status;
/// True while media/voice content is still uploading. While set,
/// [content] holds a local file path instead of a download URL.
/// Persisted to Firestore so a retry bubble survives restarts.
@override@JsonKey() final  bool uploadPending;
/// True while the local write has not been acknowledged by the server
/// (derived from snapshot metadata / a missing server timestamp).
/// Never persisted.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool isPending;
@override final  String? thumbnailUrl;
@override final  int? mediaWidth;
@override final  int? mediaHeight;
/// Duration of voice-note audio in milliseconds, measured at send time.
/// Null for non-voice messages and legacy voice notes (those fall back to
/// a one-time Storage metadata fetch).
@override final  int? durationMs;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.type, type) || other.type == type)&&(identical(other.content, content) || other.content == content)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.serverTimestamp, serverTimestamp) || other.serverTimestamp == serverTimestamp)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadPending, uploadPending) || other.uploadPending == uploadPending)&&(identical(other.isPending, isPending) || other.isPending == isPending)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.mediaWidth, mediaWidth) || other.mediaWidth == mediaWidth)&&(identical(other.mediaHeight, mediaHeight) || other.mediaHeight == mediaHeight)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,type,content,timestamp,serverTimestamp,status,uploadPending,isPending,thumbnailUrl,mediaWidth,mediaHeight,durationMs);

@override
String toString() {
  return 'Message(id: $id, conversationId: $conversationId, senderId: $senderId, type: $type, content: $content, timestamp: $timestamp, serverTimestamp: $serverTimestamp, status: $status, uploadPending: $uploadPending, isPending: $isPending, thumbnailUrl: $thumbnailUrl, mediaWidth: $mediaWidth, mediaHeight: $mediaHeight, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String conversationId, String senderId, MessageType type, String content, DateTime timestamp, DateTime? serverTimestamp,@JsonKey(unknownEnumValue: MessageStatus.sent) MessageStatus status, bool uploadPending,@JsonKey(includeFromJson: false, includeToJson: false) bool isPending, String? thumbnailUrl, int? mediaWidth, int? mediaHeight, int? durationMs
});




}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? type = null,Object? content = null,Object? timestamp = null,Object? serverTimestamp = freezed,Object? status = null,Object? uploadPending = null,Object? isPending = null,Object? thumbnailUrl = freezed,Object? mediaWidth = freezed,Object? mediaHeight = freezed,Object? durationMs = freezed,}) {
  return _then(_Message(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessageType,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,serverTimestamp: freezed == serverTimestamp ? _self.serverTimestamp : serverTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,uploadPending: null == uploadPending ? _self.uploadPending : uploadPending // ignore: cast_nullable_to_non_nullable
as bool,isPending: null == isPending ? _self.isPending : isPending // ignore: cast_nullable_to_non_nullable
as bool,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaWidth: freezed == mediaWidth ? _self.mediaWidth : mediaWidth // ignore: cast_nullable_to_non_nullable
as int?,mediaHeight: freezed == mediaHeight ? _self.mediaHeight : mediaHeight // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
