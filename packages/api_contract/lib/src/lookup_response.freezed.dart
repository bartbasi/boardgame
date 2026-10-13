// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lookup_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LookupResponse {

/// The barcode as the server normalized it: a GTIN-13 string of 13
/// digits. A 12-digit UPC-A gets one leading zero and an EAN-8 gets
/// five (docs/decisions.md 2026-10-13).
@Gtin13Converter() String get code;/// The outcome. An unrecognized value becomes [LookupStatus.unknown].
@JsonKey(unknownEnumValue: LookupStatus.unknown) LookupStatus get status;/// The matched game or the candidates; see [LookupStatus] for how many
/// each status carries.
 List<GameSummary> get games;
/// Create a copy of LookupResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LookupResponseCopyWith<LookupResponse> get copyWith => _$LookupResponseCopyWithImpl<LookupResponse>(this as LookupResponse, _$identity);

  /// Serializes this LookupResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LookupResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LookupResponse&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.games, _this.games));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LookupResponse;
  return Object.hash(runtimeType,_this.code,_this.status,const DeepCollectionEquality().hash(_this.games));
}

@override
String toString() {
  final _this = this as LookupResponse;
  return 'LookupResponse(code: ${_this.code}, status: ${_this.status}, games: ${_this.games})';
}


}

/// @nodoc
abstract mixin class $LookupResponseCopyWith<$Res>  {
  factory $LookupResponseCopyWith(LookupResponse value, $Res Function(LookupResponse) _then) = _$LookupResponseCopyWithImpl;
@useResult
$Res call({
@Gtin13Converter() String code,@JsonKey(unknownEnumValue: LookupStatus.unknown) LookupStatus status, List<GameSummary> games
});




}
/// @nodoc
class _$LookupResponseCopyWithImpl<$Res>
    implements $LookupResponseCopyWith<$Res> {
  _$LookupResponseCopyWithImpl(this._self, this._then);

  final LookupResponse _self;
  final $Res Function(LookupResponse) _then;

/// Create a copy of LookupResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? status = null,Object? games = null,}) {
  return _then(LookupResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LookupStatus,games: null == games ? _self.games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [LookupResponse].
extension LookupResponsePatterns on LookupResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LookupResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LookupResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LookupResponse value)  $default,){
final _that = this;
switch (_that) {
case _LookupResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LookupResponse value)?  $default,){
final _that = this;
switch (_that) {
case _LookupResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Gtin13Converter()  String code, @JsonKey(unknownEnumValue: LookupStatus.unknown)  LookupStatus status,  List<GameSummary> games)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LookupResponse() when $default != null:
return $default(_that.code,_that.status,_that.games);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Gtin13Converter()  String code, @JsonKey(unknownEnumValue: LookupStatus.unknown)  LookupStatus status,  List<GameSummary> games)  $default,) {final _that = this;
switch (_that) {
case _LookupResponse():
return $default(_that.code,_that.status,_that.games);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Gtin13Converter()  String code, @JsonKey(unknownEnumValue: LookupStatus.unknown)  LookupStatus status,  List<GameSummary> games)?  $default,) {final _that = this;
switch (_that) {
case _LookupResponse() when $default != null:
return $default(_that.code,_that.status,_that.games);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LookupResponse implements LookupResponse {
  const _LookupResponse({@Gtin13Converter() required this.code, @JsonKey(unknownEnumValue: LookupStatus.unknown) required this.status, required  List<GameSummary> games}): _games = games;
  factory _LookupResponse.fromJson(Map<String, dynamic> json) => _$LookupResponseFromJson(json);

/// The barcode as the server normalized it: a GTIN-13 string of 13
/// digits. A 12-digit UPC-A gets one leading zero and an EAN-8 gets
/// five (docs/decisions.md 2026-10-13).
@override@Gtin13Converter() final  String code;
/// The outcome. An unrecognized value becomes [LookupStatus.unknown].
@override@JsonKey(unknownEnumValue: LookupStatus.unknown) final  LookupStatus status;
/// The matched game or the candidates; see [LookupStatus] for how many
/// each status carries.
 final  List<GameSummary> _games;
/// The matched game or the candidates; see [LookupStatus] for how many
/// each status carries.
@override List<GameSummary> get games {
  if (_games is EqualUnmodifiableListView) return _games;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_games);
}


/// Create a copy of LookupResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LookupResponseCopyWith<_LookupResponse> get copyWith => __$LookupResponseCopyWithImpl<_LookupResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LookupResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LookupResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.games, _games));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,status,const DeepCollectionEquality().hash(_games));
}

@override
String toString() {
    return 'LookupResponse(code: $code, status: $status, games: $games)';
}


}

/// @nodoc
abstract mixin class _$LookupResponseCopyWith<$Res> implements $LookupResponseCopyWith<$Res> {
  factory _$LookupResponseCopyWith(_LookupResponse value, $Res Function(_LookupResponse) _then) = __$LookupResponseCopyWithImpl;
@override @useResult
$Res call({
@Gtin13Converter() String code,@JsonKey(unknownEnumValue: LookupStatus.unknown) LookupStatus status, List<GameSummary> games
});




}
/// @nodoc
class __$LookupResponseCopyWithImpl<$Res>
    implements _$LookupResponseCopyWith<$Res> {
  __$LookupResponseCopyWithImpl(this._self, this._then);

  final _LookupResponse _self;
  final $Res Function(_LookupResponse) _then;

/// Create a copy of LookupResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? status = null,Object? games = null,}) {
  return _then(_LookupResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LookupStatus,games: null == games ? _self._games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}


}

// dart format on
