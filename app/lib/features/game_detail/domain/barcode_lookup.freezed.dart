// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'barcode_lookup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BarcodeLookup {

/// The barcode as a 13-digit key (`Barcode.gtin13`). Always the code
/// that was looked up.
 String get gtin13;/// The outcome.
 BarcodeLookupStatus get status;/// The matched game or the candidates, in the backend's ranking order.
 List<GameSummary> get games;
/// Create a copy of BarcodeLookup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BarcodeLookupCopyWith<BarcodeLookup> get copyWith => _$BarcodeLookupCopyWithImpl<BarcodeLookup>(this as BarcodeLookup, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BarcodeLookup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BarcodeLookup&&(identical(other.gtin13, _this.gtin13) || other.gtin13 == _this.gtin13)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.games, _this.games));
}


@override
int get hashCode {
  final _this = this as BarcodeLookup;
  return Object.hash(runtimeType,_this.gtin13,_this.status,const DeepCollectionEquality().hash(_this.games));
}

@override
String toString() {
  final _this = this as BarcodeLookup;
  return 'BarcodeLookup(gtin13: ${_this.gtin13}, status: ${_this.status}, games: ${_this.games})';
}


}

/// @nodoc
abstract mixin class $BarcodeLookupCopyWith<$Res>  {
  factory $BarcodeLookupCopyWith(BarcodeLookup value, $Res Function(BarcodeLookup) _then) = _$BarcodeLookupCopyWithImpl;
@useResult
$Res call({
 String gtin13, BarcodeLookupStatus status, List<GameSummary> games
});




}
/// @nodoc
class _$BarcodeLookupCopyWithImpl<$Res>
    implements $BarcodeLookupCopyWith<$Res> {
  _$BarcodeLookupCopyWithImpl(this._self, this._then);

  final BarcodeLookup _self;
  final $Res Function(BarcodeLookup) _then;

/// Create a copy of BarcodeLookup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gtin13 = null,Object? status = null,Object? games = null,}) {
  return _then(BarcodeLookup(
gtin13: null == gtin13 ? _self.gtin13 : gtin13 // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BarcodeLookupStatus,games: null == games ? _self.games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [BarcodeLookup].
extension BarcodeLookupPatterns on BarcodeLookup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BarcodeLookup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BarcodeLookup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BarcodeLookup value)  $default,){
final _that = this;
switch (_that) {
case _BarcodeLookup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BarcodeLookup value)?  $default,){
final _that = this;
switch (_that) {
case _BarcodeLookup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String gtin13,  BarcodeLookupStatus status,  List<GameSummary> games)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BarcodeLookup() when $default != null:
return $default(_that.gtin13,_that.status,_that.games);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String gtin13,  BarcodeLookupStatus status,  List<GameSummary> games)  $default,) {final _that = this;
switch (_that) {
case _BarcodeLookup():
return $default(_that.gtin13,_that.status,_that.games);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String gtin13,  BarcodeLookupStatus status,  List<GameSummary> games)?  $default,) {final _that = this;
switch (_that) {
case _BarcodeLookup() when $default != null:
return $default(_that.gtin13,_that.status,_that.games);case _:
  return null;

}
}

}

/// @nodoc


class _BarcodeLookup implements BarcodeLookup {
  const _BarcodeLookup({required this.gtin13, required this.status, required  List<GameSummary> games}): _games = games;
  

/// The barcode as a 13-digit key (`Barcode.gtin13`). Always the code
/// that was looked up.
@override final  String gtin13;
/// The outcome.
@override final  BarcodeLookupStatus status;
/// The matched game or the candidates, in the backend's ranking order.
 final  List<GameSummary> _games;
/// The matched game or the candidates, in the backend's ranking order.
@override List<GameSummary> get games {
  if (_games is EqualUnmodifiableListView) return _games;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_games);
}


/// Create a copy of BarcodeLookup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BarcodeLookupCopyWith<_BarcodeLookup> get copyWith => __$BarcodeLookupCopyWithImpl<_BarcodeLookup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BarcodeLookup&&(identical(other.gtin13, gtin13) || other.gtin13 == gtin13)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.games, _games));
}


@override
int get hashCode {
    return Object.hash(runtimeType,gtin13,status,const DeepCollectionEquality().hash(_games));
}

@override
String toString() {
    return 'BarcodeLookup(gtin13: $gtin13, status: $status, games: $games)';
}


}

/// @nodoc
abstract mixin class _$BarcodeLookupCopyWith<$Res> implements $BarcodeLookupCopyWith<$Res> {
  factory _$BarcodeLookupCopyWith(_BarcodeLookup value, $Res Function(_BarcodeLookup) _then) = __$BarcodeLookupCopyWithImpl;
@override @useResult
$Res call({
 String gtin13, BarcodeLookupStatus status, List<GameSummary> games
});




}
/// @nodoc
class __$BarcodeLookupCopyWithImpl<$Res>
    implements _$BarcodeLookupCopyWith<$Res> {
  __$BarcodeLookupCopyWithImpl(this._self, this._then);

  final _BarcodeLookup _self;
  final $Res Function(_BarcodeLookup) _then;

/// Create a copy of BarcodeLookup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gtin13 = null,Object? status = null,Object? games = null,}) {
  return _then(_BarcodeLookup(
gtin13: null == gtin13 ? _self.gtin13 : gtin13 // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BarcodeLookupStatus,games: null == games ? _self._games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}


}

// dart format on
