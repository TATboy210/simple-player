// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'events.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayerEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PlayerEvent()';
}


}

/// @nodoc
class $PlayerEventCopyWith<$Res>  {
$PlayerEventCopyWith(PlayerEvent _, $Res Function(PlayerEvent) __);
}


/// Adds pattern-matching-related methods to [PlayerEvent].
extension PlayerEventPatterns on PlayerEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlayerEvent_Position value)?  position,TResult Function( PlayerEvent_Duration value)?  duration,TResult Function( PlayerEvent_Paused value)?  paused,TResult Function( PlayerEvent_State value)?  state,TResult Function( PlayerEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlayerEvent_Position() when position != null:
return position(_that);case PlayerEvent_Duration() when duration != null:
return duration(_that);case PlayerEvent_Paused() when paused != null:
return paused(_that);case PlayerEvent_State() when state != null:
return state(_that);case PlayerEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlayerEvent_Position value)  position,required TResult Function( PlayerEvent_Duration value)  duration,required TResult Function( PlayerEvent_Paused value)  paused,required TResult Function( PlayerEvent_State value)  state,required TResult Function( PlayerEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case PlayerEvent_Position():
return position(_that);case PlayerEvent_Duration():
return duration(_that);case PlayerEvent_Paused():
return paused(_that);case PlayerEvent_State():
return state(_that);case PlayerEvent_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlayerEvent_Position value)?  position,TResult? Function( PlayerEvent_Duration value)?  duration,TResult? Function( PlayerEvent_Paused value)?  paused,TResult? Function( PlayerEvent_State value)?  state,TResult? Function( PlayerEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case PlayerEvent_Position() when position != null:
return position(_that);case PlayerEvent_Duration() when duration != null:
return duration(_that);case PlayerEvent_Paused() when paused != null:
return paused(_that);case PlayerEvent_State() when state != null:
return state(_that);case PlayerEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double ms)?  position,TResult Function( double ms)?  duration,TResult Function( bool paused)?  paused,TResult Function( String state)?  state,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlayerEvent_Position() when position != null:
return position(_that.ms);case PlayerEvent_Duration() when duration != null:
return duration(_that.ms);case PlayerEvent_Paused() when paused != null:
return paused(_that.paused);case PlayerEvent_State() when state != null:
return state(_that.state);case PlayerEvent_Error() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double ms)  position,required TResult Function( double ms)  duration,required TResult Function( bool paused)  paused,required TResult Function( String state)  state,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case PlayerEvent_Position():
return position(_that.ms);case PlayerEvent_Duration():
return duration(_that.ms);case PlayerEvent_Paused():
return paused(_that.paused);case PlayerEvent_State():
return state(_that.state);case PlayerEvent_Error():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double ms)?  position,TResult? Function( double ms)?  duration,TResult? Function( bool paused)?  paused,TResult? Function( String state)?  state,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case PlayerEvent_Position() when position != null:
return position(_that.ms);case PlayerEvent_Duration() when duration != null:
return duration(_that.ms);case PlayerEvent_Paused() when paused != null:
return paused(_that.paused);case PlayerEvent_State() when state != null:
return state(_that.state);case PlayerEvent_Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class PlayerEvent_Position extends PlayerEvent {
  const PlayerEvent_Position({required this.ms}): super._();
  

 final  double ms;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerEvent_PositionCopyWith<PlayerEvent_Position> get copyWith => _$PlayerEvent_PositionCopyWithImpl<PlayerEvent_Position>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent_Position&&(identical(other.ms, ms) || other.ms == ms));
}


@override
int get hashCode => Object.hash(runtimeType,ms);

@override
String toString() {
  return 'PlayerEvent.position(ms: $ms)';
}


}

/// @nodoc
abstract mixin class $PlayerEvent_PositionCopyWith<$Res> implements $PlayerEventCopyWith<$Res> {
  factory $PlayerEvent_PositionCopyWith(PlayerEvent_Position value, $Res Function(PlayerEvent_Position) _then) = _$PlayerEvent_PositionCopyWithImpl;
@useResult
$Res call({
 double ms
});




}
/// @nodoc
class _$PlayerEvent_PositionCopyWithImpl<$Res>
    implements $PlayerEvent_PositionCopyWith<$Res> {
  _$PlayerEvent_PositionCopyWithImpl(this._self, this._then);

  final PlayerEvent_Position _self;
  final $Res Function(PlayerEvent_Position) _then;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ms = null,}) {
  return _then(PlayerEvent_Position(
ms: null == ms ? _self.ms : ms // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PlayerEvent_Duration extends PlayerEvent {
  const PlayerEvent_Duration({required this.ms}): super._();
  

 final  double ms;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerEvent_DurationCopyWith<PlayerEvent_Duration> get copyWith => _$PlayerEvent_DurationCopyWithImpl<PlayerEvent_Duration>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent_Duration&&(identical(other.ms, ms) || other.ms == ms));
}


@override
int get hashCode => Object.hash(runtimeType,ms);

@override
String toString() {
  return 'PlayerEvent.duration(ms: $ms)';
}


}

/// @nodoc
abstract mixin class $PlayerEvent_DurationCopyWith<$Res> implements $PlayerEventCopyWith<$Res> {
  factory $PlayerEvent_DurationCopyWith(PlayerEvent_Duration value, $Res Function(PlayerEvent_Duration) _then) = _$PlayerEvent_DurationCopyWithImpl;
@useResult
$Res call({
 double ms
});




}
/// @nodoc
class _$PlayerEvent_DurationCopyWithImpl<$Res>
    implements $PlayerEvent_DurationCopyWith<$Res> {
  _$PlayerEvent_DurationCopyWithImpl(this._self, this._then);

  final PlayerEvent_Duration _self;
  final $Res Function(PlayerEvent_Duration) _then;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ms = null,}) {
  return _then(PlayerEvent_Duration(
ms: null == ms ? _self.ms : ms // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PlayerEvent_Paused extends PlayerEvent {
  const PlayerEvent_Paused({required this.paused}): super._();
  

 final  bool paused;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerEvent_PausedCopyWith<PlayerEvent_Paused> get copyWith => _$PlayerEvent_PausedCopyWithImpl<PlayerEvent_Paused>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent_Paused&&(identical(other.paused, paused) || other.paused == paused));
}


@override
int get hashCode => Object.hash(runtimeType,paused);

@override
String toString() {
  return 'PlayerEvent.paused(paused: $paused)';
}


}

/// @nodoc
abstract mixin class $PlayerEvent_PausedCopyWith<$Res> implements $PlayerEventCopyWith<$Res> {
  factory $PlayerEvent_PausedCopyWith(PlayerEvent_Paused value, $Res Function(PlayerEvent_Paused) _then) = _$PlayerEvent_PausedCopyWithImpl;
@useResult
$Res call({
 bool paused
});




}
/// @nodoc
class _$PlayerEvent_PausedCopyWithImpl<$Res>
    implements $PlayerEvent_PausedCopyWith<$Res> {
  _$PlayerEvent_PausedCopyWithImpl(this._self, this._then);

  final PlayerEvent_Paused _self;
  final $Res Function(PlayerEvent_Paused) _then;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? paused = null,}) {
  return _then(PlayerEvent_Paused(
paused: null == paused ? _self.paused : paused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class PlayerEvent_State extends PlayerEvent {
  const PlayerEvent_State({required this.state}): super._();
  

 final  String state;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerEvent_StateCopyWith<PlayerEvent_State> get copyWith => _$PlayerEvent_StateCopyWithImpl<PlayerEvent_State>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent_State&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode => Object.hash(runtimeType,state);

@override
String toString() {
  return 'PlayerEvent.state(state: $state)';
}


}

/// @nodoc
abstract mixin class $PlayerEvent_StateCopyWith<$Res> implements $PlayerEventCopyWith<$Res> {
  factory $PlayerEvent_StateCopyWith(PlayerEvent_State value, $Res Function(PlayerEvent_State) _then) = _$PlayerEvent_StateCopyWithImpl;
@useResult
$Res call({
 String state
});




}
/// @nodoc
class _$PlayerEvent_StateCopyWithImpl<$Res>
    implements $PlayerEvent_StateCopyWith<$Res> {
  _$PlayerEvent_StateCopyWithImpl(this._self, this._then);

  final PlayerEvent_State _self;
  final $Res Function(PlayerEvent_State) _then;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(PlayerEvent_State(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PlayerEvent_Error extends PlayerEvent {
  const PlayerEvent_Error({required this.message}): super._();
  

 final  String message;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerEvent_ErrorCopyWith<PlayerEvent_Error> get copyWith => _$PlayerEvent_ErrorCopyWithImpl<PlayerEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerEvent_Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'PlayerEvent.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $PlayerEvent_ErrorCopyWith<$Res> implements $PlayerEventCopyWith<$Res> {
  factory $PlayerEvent_ErrorCopyWith(PlayerEvent_Error value, $Res Function(PlayerEvent_Error) _then) = _$PlayerEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$PlayerEvent_ErrorCopyWithImpl<$Res>
    implements $PlayerEvent_ErrorCopyWith<$Res> {
  _$PlayerEvent_ErrorCopyWithImpl(this._self, this._then);

  final PlayerEvent_Error _self;
  final $Res Function(PlayerEvent_Error) _then;

/// Create a copy of PlayerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(PlayerEvent_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
