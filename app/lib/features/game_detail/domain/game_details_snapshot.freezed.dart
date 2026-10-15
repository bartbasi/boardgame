// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_details_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GameDetailsSnapshot {

/// The game's details.
 GameDetails get details;/// Fresh from the backend, or the stale cached copy.
 DataFreshness get freshness;/// When this device received the details from the backend (UTC): now
/// for a fresh load, the time it was cached for a stale copy. The
/// backend's own fetch time from BGG is [GameDetails.fetchedAt].
 DateTime get fetchedAt;/// Why the refresh failed when this is the stale cached copy, so the
/// screen can say the right thing (offline, the service is down, or
/// BoardGameGeek no longer lists the game for [NotFoundFailure]); null
/// for a fresh load (T-029 review R2-S1).
 Failure? get refreshFailure;
/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameDetailsSnapshotCopyWith<GameDetailsSnapshot> get copyWith => _$GameDetailsSnapshotCopyWithImpl<GameDetailsSnapshot>(this as GameDetailsSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GameDetailsSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameDetailsSnapshot&&(identical(other.details, _this.details) || other.details == _this.details)&&(identical(other.freshness, _this.freshness) || other.freshness == _this.freshness)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt)&&(identical(other.refreshFailure, _this.refreshFailure) || other.refreshFailure == _this.refreshFailure));
}


@override
int get hashCode {
  final _this = this as GameDetailsSnapshot;
  return Object.hash(runtimeType,_this.details,_this.freshness,_this.fetchedAt,_this.refreshFailure);
}

@override
String toString() {
  final _this = this as GameDetailsSnapshot;
  return 'GameDetailsSnapshot(details: ${_this.details}, freshness: ${_this.freshness}, fetchedAt: ${_this.fetchedAt}, refreshFailure: ${_this.refreshFailure})';
}


}

/// @nodoc
abstract mixin class $GameDetailsSnapshotCopyWith<$Res>  {
  factory $GameDetailsSnapshotCopyWith(GameDetailsSnapshot value, $Res Function(GameDetailsSnapshot) _then) = _$GameDetailsSnapshotCopyWithImpl;
@useResult
$Res call({
 GameDetails details, DataFreshness freshness, DateTime fetchedAt, Failure? refreshFailure
});


$GameDetailsCopyWith<$Res> get details;

}
/// @nodoc
class _$GameDetailsSnapshotCopyWithImpl<$Res>
    implements $GameDetailsSnapshotCopyWith<$Res> {
  _$GameDetailsSnapshotCopyWithImpl(this._self, this._then);

  final GameDetailsSnapshot _self;
  final $Res Function(GameDetailsSnapshot) _then;

/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? details = null,Object? freshness = null,Object? fetchedAt = null,Object? refreshFailure = freezed,}) {
  return _then(GameDetailsSnapshot(
details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as GameDetails,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,refreshFailure: freezed == refreshFailure ? _self.refreshFailure : refreshFailure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}
/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameDetailsCopyWith<$Res> get details {
  
  return $GameDetailsCopyWith<$Res>(_self.details, (value) {
    return _then(_self.copyWith(details: value));
  });
}
}


/// Adds pattern-matching-related methods to [GameDetailsSnapshot].
extension GameDetailsSnapshotPatterns on GameDetailsSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameDetailsSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameDetailsSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameDetailsSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _GameDetailsSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameDetailsSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _GameDetailsSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GameDetails details,  DataFreshness freshness,  DateTime fetchedAt,  Failure? refreshFailure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameDetailsSnapshot() when $default != null:
return $default(_that.details,_that.freshness,_that.fetchedAt,_that.refreshFailure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GameDetails details,  DataFreshness freshness,  DateTime fetchedAt,  Failure? refreshFailure)  $default,) {final _that = this;
switch (_that) {
case _GameDetailsSnapshot():
return $default(_that.details,_that.freshness,_that.fetchedAt,_that.refreshFailure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GameDetails details,  DataFreshness freshness,  DateTime fetchedAt,  Failure? refreshFailure)?  $default,) {final _that = this;
switch (_that) {
case _GameDetailsSnapshot() when $default != null:
return $default(_that.details,_that.freshness,_that.fetchedAt,_that.refreshFailure);case _:
  return null;

}
}

}

/// @nodoc


class _GameDetailsSnapshot extends GameDetailsSnapshot {
  const _GameDetailsSnapshot({required this.details, required this.freshness, required this.fetchedAt, this.refreshFailure}): super._();
  

/// The game's details.
@override final  GameDetails details;
/// Fresh from the backend, or the stale cached copy.
@override final  DataFreshness freshness;
/// When this device received the details from the backend (UTC): now
/// for a fresh load, the time it was cached for a stale copy. The
/// backend's own fetch time from BGG is [GameDetails.fetchedAt].
@override final  DateTime fetchedAt;
/// Why the refresh failed when this is the stale cached copy, so the
/// screen can say the right thing (offline, the service is down, or
/// BoardGameGeek no longer lists the game for [NotFoundFailure]); null
/// for a fresh load (T-029 review R2-S1).
@override final  Failure? refreshFailure;

/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameDetailsSnapshotCopyWith<_GameDetailsSnapshot> get copyWith => __$GameDetailsSnapshotCopyWithImpl<_GameDetailsSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameDetailsSnapshot&&(identical(other.details, details) || other.details == details)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.refreshFailure, refreshFailure) || other.refreshFailure == refreshFailure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,details,freshness,fetchedAt,refreshFailure);
}

@override
String toString() {
    return 'GameDetailsSnapshot(details: $details, freshness: $freshness, fetchedAt: $fetchedAt, refreshFailure: $refreshFailure)';
}


}

/// @nodoc
abstract mixin class _$GameDetailsSnapshotCopyWith<$Res> implements $GameDetailsSnapshotCopyWith<$Res> {
  factory _$GameDetailsSnapshotCopyWith(_GameDetailsSnapshot value, $Res Function(_GameDetailsSnapshot) _then) = __$GameDetailsSnapshotCopyWithImpl;
@override @useResult
$Res call({
 GameDetails details, DataFreshness freshness, DateTime fetchedAt, Failure? refreshFailure
});


@override $GameDetailsCopyWith<$Res> get details;

}
/// @nodoc
class __$GameDetailsSnapshotCopyWithImpl<$Res>
    implements _$GameDetailsSnapshotCopyWith<$Res> {
  __$GameDetailsSnapshotCopyWithImpl(this._self, this._then);

  final _GameDetailsSnapshot _self;
  final $Res Function(_GameDetailsSnapshot) _then;

/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? details = null,Object? freshness = null,Object? fetchedAt = null,Object? refreshFailure = freezed,}) {
  return _then(_GameDetailsSnapshot(
details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as GameDetails,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,refreshFailure: freezed == refreshFailure ? _self.refreshFailure : refreshFailure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

/// Create a copy of GameDetailsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameDetailsCopyWith<$Res> get details {
  
  return $GameDetailsCopyWith<$Res>(_self.details, (value) {
    return _then(_self.copyWith(details: value));
  });
}
}

// dart format on
