// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 String get id; ConversationType get type; List<String> get participantIds; String? get title; DateTime get createdAt; DateTime? get lastMessageAt; String? get lastMessagePreview; Map<String, int> get unreadCounts; Map<String, DateTime> get lastDeliveredAtByUser; Map<String, DateTime> get lastReadAtByUser; String get createdBy;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.participantIds, participantIds)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&const DeepCollectionEquality().equals(other.unreadCounts, unreadCounts)&&const DeepCollectionEquality().equals(other.lastDeliveredAtByUser, lastDeliveredAtByUser)&&const DeepCollectionEquality().equals(other.lastReadAtByUser, lastReadAtByUser)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,const DeepCollectionEquality().hash(participantIds),title,createdAt,lastMessageAt,lastMessagePreview,const DeepCollectionEquality().hash(unreadCounts),const DeepCollectionEquality().hash(lastDeliveredAtByUser),const DeepCollectionEquality().hash(lastReadAtByUser),createdBy);

@override
String toString() {
  return 'Conversation(id: $id, type: $type, participantIds: $participantIds, title: $title, createdAt: $createdAt, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, unreadCounts: $unreadCounts, lastDeliveredAtByUser: $lastDeliveredAtByUser, lastReadAtByUser: $lastReadAtByUser, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String id, ConversationType type, List<String> participantIds, String? title, DateTime createdAt, DateTime? lastMessageAt, String? lastMessagePreview, Map<String, int> unreadCounts, Map<String, DateTime> lastDeliveredAtByUser, Map<String, DateTime> lastReadAtByUser, String createdBy
});




}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? participantIds = null,Object? title = freezed,Object? createdAt = null,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? unreadCounts = null,Object? lastDeliveredAtByUser = null,Object? lastReadAtByUser = null,Object? createdBy = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ConversationType,participantIds: null == participantIds ? _self.participantIds : participantIds // ignore: cast_nullable_to_non_nullable
as List<String>,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,unreadCounts: null == unreadCounts ? _self.unreadCounts : unreadCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lastDeliveredAtByUser: null == lastDeliveredAtByUser ? _self.lastDeliveredAtByUser : lastDeliveredAtByUser // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,lastReadAtByUser: null == lastReadAtByUser ? _self.lastReadAtByUser : lastReadAtByUser // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  ConversationType type,  List<String> participantIds,  String? title,  DateTime createdAt,  DateTime? lastMessageAt,  String? lastMessagePreview,  Map<String, int> unreadCounts,  Map<String, DateTime> lastDeliveredAtByUser,  Map<String, DateTime> lastReadAtByUser,  String createdBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.participantIds,_that.title,_that.createdAt,_that.lastMessageAt,_that.lastMessagePreview,_that.unreadCounts,_that.lastDeliveredAtByUser,_that.lastReadAtByUser,_that.createdBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  ConversationType type,  List<String> participantIds,  String? title,  DateTime createdAt,  DateTime? lastMessageAt,  String? lastMessagePreview,  Map<String, int> unreadCounts,  Map<String, DateTime> lastDeliveredAtByUser,  Map<String, DateTime> lastReadAtByUser,  String createdBy)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.type,_that.participantIds,_that.title,_that.createdAt,_that.lastMessageAt,_that.lastMessagePreview,_that.unreadCounts,_that.lastDeliveredAtByUser,_that.lastReadAtByUser,_that.createdBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  ConversationType type,  List<String> participantIds,  String? title,  DateTime createdAt,  DateTime? lastMessageAt,  String? lastMessagePreview,  Map<String, int> unreadCounts,  Map<String, DateTime> lastDeliveredAtByUser,  Map<String, DateTime> lastReadAtByUser,  String createdBy)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.participantIds,_that.title,_that.createdAt,_that.lastMessageAt,_that.lastMessagePreview,_that.unreadCounts,_that.lastDeliveredAtByUser,_that.lastReadAtByUser,_that.createdBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation implements Conversation {
  const _Conversation({required this.id, required this.type, required final  List<String> participantIds, this.title, required this.createdAt, this.lastMessageAt, this.lastMessagePreview, final  Map<String, int> unreadCounts = const <String, int>{}, final  Map<String, DateTime> lastDeliveredAtByUser = const <String, DateTime>{}, final  Map<String, DateTime> lastReadAtByUser = const <String, DateTime>{}, required this.createdBy}): _participantIds = participantIds,_unreadCounts = unreadCounts,_lastDeliveredAtByUser = lastDeliveredAtByUser,_lastReadAtByUser = lastReadAtByUser;
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  String id;
@override final  ConversationType type;
 final  List<String> _participantIds;
@override List<String> get participantIds {
  if (_participantIds is EqualUnmodifiableListView) return _participantIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participantIds);
}

@override final  String? title;
@override final  DateTime createdAt;
@override final  DateTime? lastMessageAt;
@override final  String? lastMessagePreview;
 final  Map<String, int> _unreadCounts;
@override@JsonKey() Map<String, int> get unreadCounts {
  if (_unreadCounts is EqualUnmodifiableMapView) return _unreadCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unreadCounts);
}

 final  Map<String, DateTime> _lastDeliveredAtByUser;
@override@JsonKey() Map<String, DateTime> get lastDeliveredAtByUser {
  if (_lastDeliveredAtByUser is EqualUnmodifiableMapView) return _lastDeliveredAtByUser;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lastDeliveredAtByUser);
}

 final  Map<String, DateTime> _lastReadAtByUser;
@override@JsonKey() Map<String, DateTime> get lastReadAtByUser {
  if (_lastReadAtByUser is EqualUnmodifiableMapView) return _lastReadAtByUser;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lastReadAtByUser);
}

@override final  String createdBy;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._participantIds, _participantIds)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&const DeepCollectionEquality().equals(other._unreadCounts, _unreadCounts)&&const DeepCollectionEquality().equals(other._lastDeliveredAtByUser, _lastDeliveredAtByUser)&&const DeepCollectionEquality().equals(other._lastReadAtByUser, _lastReadAtByUser)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,const DeepCollectionEquality().hash(_participantIds),title,createdAt,lastMessageAt,lastMessagePreview,const DeepCollectionEquality().hash(_unreadCounts),const DeepCollectionEquality().hash(_lastDeliveredAtByUser),const DeepCollectionEquality().hash(_lastReadAtByUser),createdBy);

@override
String toString() {
  return 'Conversation(id: $id, type: $type, participantIds: $participantIds, title: $title, createdAt: $createdAt, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, unreadCounts: $unreadCounts, lastDeliveredAtByUser: $lastDeliveredAtByUser, lastReadAtByUser: $lastReadAtByUser, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, ConversationType type, List<String> participantIds, String? title, DateTime createdAt, DateTime? lastMessageAt, String? lastMessagePreview, Map<String, int> unreadCounts, Map<String, DateTime> lastDeliveredAtByUser, Map<String, DateTime> lastReadAtByUser, String createdBy
});




}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? participantIds = null,Object? title = freezed,Object? createdAt = null,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? unreadCounts = null,Object? lastDeliveredAtByUser = null,Object? lastReadAtByUser = null,Object? createdBy = null,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ConversationType,participantIds: null == participantIds ? _self._participantIds : participantIds // ignore: cast_nullable_to_non_nullable
as List<String>,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,unreadCounts: null == unreadCounts ? _self._unreadCounts : unreadCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lastDeliveredAtByUser: null == lastDeliveredAtByUser ? _self._lastDeliveredAtByUser : lastDeliveredAtByUser // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,lastReadAtByUser: null == lastReadAtByUser ? _self._lastReadAtByUser : lastReadAtByUser // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
