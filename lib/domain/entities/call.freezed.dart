// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'call.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IceCandidate {

 String get id; String get candidate; String get sdpMid; int get sdpMLineIndex; String get fromUserId; DateTime get createdAt;
/// Create a copy of IceCandidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IceCandidateCopyWith<IceCandidate> get copyWith => _$IceCandidateCopyWithImpl<IceCandidate>(this as IceCandidate, _$identity);

  /// Serializes this IceCandidate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IceCandidate&&(identical(other.id, id) || other.id == id)&&(identical(other.candidate, candidate) || other.candidate == candidate)&&(identical(other.sdpMid, sdpMid) || other.sdpMid == sdpMid)&&(identical(other.sdpMLineIndex, sdpMLineIndex) || other.sdpMLineIndex == sdpMLineIndex)&&(identical(other.fromUserId, fromUserId) || other.fromUserId == fromUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,candidate,sdpMid,sdpMLineIndex,fromUserId,createdAt);

@override
String toString() {
  return 'IceCandidate(id: $id, candidate: $candidate, sdpMid: $sdpMid, sdpMLineIndex: $sdpMLineIndex, fromUserId: $fromUserId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $IceCandidateCopyWith<$Res>  {
  factory $IceCandidateCopyWith(IceCandidate value, $Res Function(IceCandidate) _then) = _$IceCandidateCopyWithImpl;
@useResult
$Res call({
 String id, String candidate, String sdpMid, int sdpMLineIndex, String fromUserId, DateTime createdAt
});




}
/// @nodoc
class _$IceCandidateCopyWithImpl<$Res>
    implements $IceCandidateCopyWith<$Res> {
  _$IceCandidateCopyWithImpl(this._self, this._then);

  final IceCandidate _self;
  final $Res Function(IceCandidate) _then;

/// Create a copy of IceCandidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? candidate = null,Object? sdpMid = null,Object? sdpMLineIndex = null,Object? fromUserId = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,candidate: null == candidate ? _self.candidate : candidate // ignore: cast_nullable_to_non_nullable
as String,sdpMid: null == sdpMid ? _self.sdpMid : sdpMid // ignore: cast_nullable_to_non_nullable
as String,sdpMLineIndex: null == sdpMLineIndex ? _self.sdpMLineIndex : sdpMLineIndex // ignore: cast_nullable_to_non_nullable
as int,fromUserId: null == fromUserId ? _self.fromUserId : fromUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [IceCandidate].
extension IceCandidatePatterns on IceCandidate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IceCandidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IceCandidate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IceCandidate value)  $default,){
final _that = this;
switch (_that) {
case _IceCandidate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IceCandidate value)?  $default,){
final _that = this;
switch (_that) {
case _IceCandidate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String candidate,  String sdpMid,  int sdpMLineIndex,  String fromUserId,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IceCandidate() when $default != null:
return $default(_that.id,_that.candidate,_that.sdpMid,_that.sdpMLineIndex,_that.fromUserId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String candidate,  String sdpMid,  int sdpMLineIndex,  String fromUserId,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _IceCandidate():
return $default(_that.id,_that.candidate,_that.sdpMid,_that.sdpMLineIndex,_that.fromUserId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String candidate,  String sdpMid,  int sdpMLineIndex,  String fromUserId,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _IceCandidate() when $default != null:
return $default(_that.id,_that.candidate,_that.sdpMid,_that.sdpMLineIndex,_that.fromUserId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IceCandidate implements IceCandidate {
  const _IceCandidate({required this.id, required this.candidate, required this.sdpMid, required this.sdpMLineIndex, required this.fromUserId, required this.createdAt});
  factory _IceCandidate.fromJson(Map<String, dynamic> json) => _$IceCandidateFromJson(json);

@override final  String id;
@override final  String candidate;
@override final  String sdpMid;
@override final  int sdpMLineIndex;
@override final  String fromUserId;
@override final  DateTime createdAt;

/// Create a copy of IceCandidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IceCandidateCopyWith<_IceCandidate> get copyWith => __$IceCandidateCopyWithImpl<_IceCandidate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IceCandidateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IceCandidate&&(identical(other.id, id) || other.id == id)&&(identical(other.candidate, candidate) || other.candidate == candidate)&&(identical(other.sdpMid, sdpMid) || other.sdpMid == sdpMid)&&(identical(other.sdpMLineIndex, sdpMLineIndex) || other.sdpMLineIndex == sdpMLineIndex)&&(identical(other.fromUserId, fromUserId) || other.fromUserId == fromUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,candidate,sdpMid,sdpMLineIndex,fromUserId,createdAt);

@override
String toString() {
  return 'IceCandidate(id: $id, candidate: $candidate, sdpMid: $sdpMid, sdpMLineIndex: $sdpMLineIndex, fromUserId: $fromUserId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$IceCandidateCopyWith<$Res> implements $IceCandidateCopyWith<$Res> {
  factory _$IceCandidateCopyWith(_IceCandidate value, $Res Function(_IceCandidate) _then) = __$IceCandidateCopyWithImpl;
@override @useResult
$Res call({
 String id, String candidate, String sdpMid, int sdpMLineIndex, String fromUserId, DateTime createdAt
});




}
/// @nodoc
class __$IceCandidateCopyWithImpl<$Res>
    implements _$IceCandidateCopyWith<$Res> {
  __$IceCandidateCopyWithImpl(this._self, this._then);

  final _IceCandidate _self;
  final $Res Function(_IceCandidate) _then;

/// Create a copy of IceCandidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? candidate = null,Object? sdpMid = null,Object? sdpMLineIndex = null,Object? fromUserId = null,Object? createdAt = null,}) {
  return _then(_IceCandidate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,candidate: null == candidate ? _self.candidate : candidate // ignore: cast_nullable_to_non_nullable
as String,sdpMid: null == sdpMid ? _self.sdpMid : sdpMid // ignore: cast_nullable_to_non_nullable
as String,sdpMLineIndex: null == sdpMLineIndex ? _self.sdpMLineIndex : sdpMLineIndex // ignore: cast_nullable_to_non_nullable
as int,fromUserId: null == fromUserId ? _self.fromUserId : fromUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Call {

 String get id; String get callerId; String get calleeId; List<String> get participantIds; String get conversationId; CallStatus get status; Map<String, dynamic>? get offer; Map<String, dynamic>? get answer; Map<String, dynamic>? get restartOffer; Map<String, dynamic>? get restartAnswer; bool get callerVideoEnabled; bool get calleeVideoEnabled; DateTime get createdAt; DateTime? get endedAt; CallEndReason? get endReason;
/// Create a copy of Call
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CallCopyWith<Call> get copyWith => _$CallCopyWithImpl<Call>(this as Call, _$identity);

  /// Serializes this Call to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Call&&(identical(other.id, id) || other.id == id)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&const DeepCollectionEquality().equals(other.participantIds, participantIds)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.offer, offer)&&const DeepCollectionEquality().equals(other.answer, answer)&&const DeepCollectionEquality().equals(other.restartOffer, restartOffer)&&const DeepCollectionEquality().equals(other.restartAnswer, restartAnswer)&&(identical(other.callerVideoEnabled, callerVideoEnabled) || other.callerVideoEnabled == callerVideoEnabled)&&(identical(other.calleeVideoEnabled, calleeVideoEnabled) || other.calleeVideoEnabled == calleeVideoEnabled)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.endReason, endReason) || other.endReason == endReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callerId,calleeId,const DeepCollectionEquality().hash(participantIds),conversationId,status,const DeepCollectionEquality().hash(offer),const DeepCollectionEquality().hash(answer),const DeepCollectionEquality().hash(restartOffer),const DeepCollectionEquality().hash(restartAnswer),callerVideoEnabled,calleeVideoEnabled,createdAt,endedAt,endReason);

@override
String toString() {
  return 'Call(id: $id, callerId: $callerId, calleeId: $calleeId, participantIds: $participantIds, conversationId: $conversationId, status: $status, offer: $offer, answer: $answer, restartOffer: $restartOffer, restartAnswer: $restartAnswer, callerVideoEnabled: $callerVideoEnabled, calleeVideoEnabled: $calleeVideoEnabled, createdAt: $createdAt, endedAt: $endedAt, endReason: $endReason)';
}


}

/// @nodoc
abstract mixin class $CallCopyWith<$Res>  {
  factory $CallCopyWith(Call value, $Res Function(Call) _then) = _$CallCopyWithImpl;
@useResult
$Res call({
 String id, String callerId, String calleeId, List<String> participantIds, String conversationId, CallStatus status, Map<String, dynamic>? offer, Map<String, dynamic>? answer, Map<String, dynamic>? restartOffer, Map<String, dynamic>? restartAnswer, bool callerVideoEnabled, bool calleeVideoEnabled, DateTime createdAt, DateTime? endedAt, CallEndReason? endReason
});




}
/// @nodoc
class _$CallCopyWithImpl<$Res>
    implements $CallCopyWith<$Res> {
  _$CallCopyWithImpl(this._self, this._then);

  final Call _self;
  final $Res Function(Call) _then;

/// Create a copy of Call
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? callerId = null,Object? calleeId = null,Object? participantIds = null,Object? conversationId = null,Object? status = null,Object? offer = freezed,Object? answer = freezed,Object? restartOffer = freezed,Object? restartAnswer = freezed,Object? callerVideoEnabled = null,Object? calleeVideoEnabled = null,Object? createdAt = null,Object? endedAt = freezed,Object? endReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,participantIds: null == participantIds ? _self.participantIds : participantIds // ignore: cast_nullable_to_non_nullable
as List<String>,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CallStatus,offer: freezed == offer ? _self.offer : offer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,answer: freezed == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,restartOffer: freezed == restartOffer ? _self.restartOffer : restartOffer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,restartAnswer: freezed == restartAnswer ? _self.restartAnswer : restartAnswer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,callerVideoEnabled: null == callerVideoEnabled ? _self.callerVideoEnabled : callerVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,calleeVideoEnabled: null == calleeVideoEnabled ? _self.calleeVideoEnabled : calleeVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as CallEndReason?,
  ));
}

}


/// Adds pattern-matching-related methods to [Call].
extension CallPatterns on Call {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Call value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Call() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Call value)  $default,){
final _that = this;
switch (_that) {
case _Call():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Call value)?  $default,){
final _that = this;
switch (_that) {
case _Call() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String callerId,  String calleeId,  List<String> participantIds,  String conversationId,  CallStatus status,  Map<String, dynamic>? offer,  Map<String, dynamic>? answer,  Map<String, dynamic>? restartOffer,  Map<String, dynamic>? restartAnswer,  bool callerVideoEnabled,  bool calleeVideoEnabled,  DateTime createdAt,  DateTime? endedAt,  CallEndReason? endReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Call() when $default != null:
return $default(_that.id,_that.callerId,_that.calleeId,_that.participantIds,_that.conversationId,_that.status,_that.offer,_that.answer,_that.restartOffer,_that.restartAnswer,_that.callerVideoEnabled,_that.calleeVideoEnabled,_that.createdAt,_that.endedAt,_that.endReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String callerId,  String calleeId,  List<String> participantIds,  String conversationId,  CallStatus status,  Map<String, dynamic>? offer,  Map<String, dynamic>? answer,  Map<String, dynamic>? restartOffer,  Map<String, dynamic>? restartAnswer,  bool callerVideoEnabled,  bool calleeVideoEnabled,  DateTime createdAt,  DateTime? endedAt,  CallEndReason? endReason)  $default,) {final _that = this;
switch (_that) {
case _Call():
return $default(_that.id,_that.callerId,_that.calleeId,_that.participantIds,_that.conversationId,_that.status,_that.offer,_that.answer,_that.restartOffer,_that.restartAnswer,_that.callerVideoEnabled,_that.calleeVideoEnabled,_that.createdAt,_that.endedAt,_that.endReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String callerId,  String calleeId,  List<String> participantIds,  String conversationId,  CallStatus status,  Map<String, dynamic>? offer,  Map<String, dynamic>? answer,  Map<String, dynamic>? restartOffer,  Map<String, dynamic>? restartAnswer,  bool callerVideoEnabled,  bool calleeVideoEnabled,  DateTime createdAt,  DateTime? endedAt,  CallEndReason? endReason)?  $default,) {final _that = this;
switch (_that) {
case _Call() when $default != null:
return $default(_that.id,_that.callerId,_that.calleeId,_that.participantIds,_that.conversationId,_that.status,_that.offer,_that.answer,_that.restartOffer,_that.restartAnswer,_that.callerVideoEnabled,_that.calleeVideoEnabled,_that.createdAt,_that.endedAt,_that.endReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Call implements Call {
  const _Call({required this.id, required this.callerId, required this.calleeId, required final  List<String> participantIds, required this.conversationId, required this.status, final  Map<String, dynamic>? offer, final  Map<String, dynamic>? answer, final  Map<String, dynamic>? restartOffer, final  Map<String, dynamic>? restartAnswer, this.callerVideoEnabled = false, this.calleeVideoEnabled = false, required this.createdAt, this.endedAt, this.endReason}): _participantIds = participantIds,_offer = offer,_answer = answer,_restartOffer = restartOffer,_restartAnswer = restartAnswer;
  factory _Call.fromJson(Map<String, dynamic> json) => _$CallFromJson(json);

@override final  String id;
@override final  String callerId;
@override final  String calleeId;
 final  List<String> _participantIds;
@override List<String> get participantIds {
  if (_participantIds is EqualUnmodifiableListView) return _participantIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participantIds);
}

@override final  String conversationId;
@override final  CallStatus status;
 final  Map<String, dynamic>? _offer;
@override Map<String, dynamic>? get offer {
  final value = _offer;
  if (value == null) return null;
  if (_offer is EqualUnmodifiableMapView) return _offer;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _answer;
@override Map<String, dynamic>? get answer {
  final value = _answer;
  if (value == null) return null;
  if (_answer is EqualUnmodifiableMapView) return _answer;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _restartOffer;
@override Map<String, dynamic>? get restartOffer {
  final value = _restartOffer;
  if (value == null) return null;
  if (_restartOffer is EqualUnmodifiableMapView) return _restartOffer;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _restartAnswer;
@override Map<String, dynamic>? get restartAnswer {
  final value = _restartAnswer;
  if (value == null) return null;
  if (_restartAnswer is EqualUnmodifiableMapView) return _restartAnswer;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool callerVideoEnabled;
@override@JsonKey() final  bool calleeVideoEnabled;
@override final  DateTime createdAt;
@override final  DateTime? endedAt;
@override final  CallEndReason? endReason;

/// Create a copy of Call
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CallCopyWith<_Call> get copyWith => __$CallCopyWithImpl<_Call>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Call&&(identical(other.id, id) || other.id == id)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&const DeepCollectionEquality().equals(other._participantIds, _participantIds)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._offer, _offer)&&const DeepCollectionEquality().equals(other._answer, _answer)&&const DeepCollectionEquality().equals(other._restartOffer, _restartOffer)&&const DeepCollectionEquality().equals(other._restartAnswer, _restartAnswer)&&(identical(other.callerVideoEnabled, callerVideoEnabled) || other.callerVideoEnabled == callerVideoEnabled)&&(identical(other.calleeVideoEnabled, calleeVideoEnabled) || other.calleeVideoEnabled == calleeVideoEnabled)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.endReason, endReason) || other.endReason == endReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callerId,calleeId,const DeepCollectionEquality().hash(_participantIds),conversationId,status,const DeepCollectionEquality().hash(_offer),const DeepCollectionEquality().hash(_answer),const DeepCollectionEquality().hash(_restartOffer),const DeepCollectionEquality().hash(_restartAnswer),callerVideoEnabled,calleeVideoEnabled,createdAt,endedAt,endReason);

@override
String toString() {
  return 'Call(id: $id, callerId: $callerId, calleeId: $calleeId, participantIds: $participantIds, conversationId: $conversationId, status: $status, offer: $offer, answer: $answer, restartOffer: $restartOffer, restartAnswer: $restartAnswer, callerVideoEnabled: $callerVideoEnabled, calleeVideoEnabled: $calleeVideoEnabled, createdAt: $createdAt, endedAt: $endedAt, endReason: $endReason)';
}


}

/// @nodoc
abstract mixin class _$CallCopyWith<$Res> implements $CallCopyWith<$Res> {
  factory _$CallCopyWith(_Call value, $Res Function(_Call) _then) = __$CallCopyWithImpl;
@override @useResult
$Res call({
 String id, String callerId, String calleeId, List<String> participantIds, String conversationId, CallStatus status, Map<String, dynamic>? offer, Map<String, dynamic>? answer, Map<String, dynamic>? restartOffer, Map<String, dynamic>? restartAnswer, bool callerVideoEnabled, bool calleeVideoEnabled, DateTime createdAt, DateTime? endedAt, CallEndReason? endReason
});




}
/// @nodoc
class __$CallCopyWithImpl<$Res>
    implements _$CallCopyWith<$Res> {
  __$CallCopyWithImpl(this._self, this._then);

  final _Call _self;
  final $Res Function(_Call) _then;

/// Create a copy of Call
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? callerId = null,Object? calleeId = null,Object? participantIds = null,Object? conversationId = null,Object? status = null,Object? offer = freezed,Object? answer = freezed,Object? restartOffer = freezed,Object? restartAnswer = freezed,Object? callerVideoEnabled = null,Object? calleeVideoEnabled = null,Object? createdAt = null,Object? endedAt = freezed,Object? endReason = freezed,}) {
  return _then(_Call(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,participantIds: null == participantIds ? _self._participantIds : participantIds // ignore: cast_nullable_to_non_nullable
as List<String>,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CallStatus,offer: freezed == offer ? _self._offer : offer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,answer: freezed == answer ? _self._answer : answer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,restartOffer: freezed == restartOffer ? _self._restartOffer : restartOffer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,restartAnswer: freezed == restartAnswer ? _self._restartAnswer : restartAnswer // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,callerVideoEnabled: null == callerVideoEnabled ? _self.callerVideoEnabled : callerVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,calleeVideoEnabled: null == calleeVideoEnabled ? _self.calleeVideoEnabled : calleeVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as CallEndReason?,
  ));
}


}

// dart format on
