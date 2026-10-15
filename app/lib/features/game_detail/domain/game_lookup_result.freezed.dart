// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_lookup_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GameLookupResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GameLookupResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GameLookupResult()';
}


}

/// @nodoc
class $GameLookupResultCopyWith<$Res>  {
$GameLookupResultCopyWith(GameLookupResult _, $Res Function(GameLookupResult) __);
}


/// Adds pattern-matching-related methods to [GameLookupResult].
extension GameLookupResultPatterns on GameLookupResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConfirmedOnDevice value)?  confirmedOnDevice,TResult Function( FromBackend value)?  fromBackend,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConfirmedOnDevice() when confirmedOnDevice != null:
return confirmedOnDevice(_that);case FromBackend() when fromBackend != null:
return fromBackend(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConfirmedOnDevice value)  confirmedOnDevice,required TResult Function( FromBackend value)  fromBackend,}){
final _that = this;
switch (_that) {
case ConfirmedOnDevice():
return confirmedOnDevice(_that);case FromBackend():
return fromBackend(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConfirmedOnDevice value)?  confirmedOnDevice,TResult? Function( FromBackend value)?  fromBackend,}){
final _that = this;
switch (_that) {
case ConfirmedOnDevice() when confirmedOnDevice != null:
return confirmedOnDevice(_that);case FromBackend() when fromBackend != null:
return fromBackend(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String gtin13,  int bggId,  DateTime confirmedAt,  GameSummary? game)?  confirmedOnDevice,TResult Function( BarcodeLookup lookup)?  fromBackend,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConfirmedOnDevice() when confirmedOnDevice != null:
return confirmedOnDevice(_that.gtin13,_that.bggId,_that.confirmedAt,_that.game);case FromBackend() when fromBackend != null:
return fromBackend(_that.lookup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String gtin13,  int bggId,  DateTime confirmedAt,  GameSummary? game)  confirmedOnDevice,required TResult Function( BarcodeLookup lookup)  fromBackend,}) {final _that = this;
switch (_that) {
case ConfirmedOnDevice():
return confirmedOnDevice(_that.gtin13,_that.bggId,_that.confirmedAt,_that.game);case FromBackend():
return fromBackend(_that.lookup);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String gtin13,  int bggId,  DateTime confirmedAt,  GameSummary? game)?  confirmedOnDevice,TResult? Function( BarcodeLookup lookup)?  fromBackend,}) {final _that = this;
switch (_that) {
case ConfirmedOnDevice() when confirmedOnDevice != null:
return confirmedOnDevice(_that.gtin13,_that.bggId,_that.confirmedAt,_that.game);case FromBackend() when fromBackend != null:
return fromBackend(_that.lookup);case _:
  return null;

}
}

}

/// @nodoc


class ConfirmedOnDevice extends GameLookupResult {
  const ConfirmedOnDevice({required this.gtin13, required this.bggId, required this.confirmedAt, this.game}): super._();
  

/// The barcode as a 13-digit key (`Barcode.gtin13`).
 final  String gtin13;
/// The game the barcode was confirmed to belong to.
 final  int bggId;
/// When the match was confirmed (UTC).
 final  DateTime confirmedAt;
/// The game's name, year, and BGG link from the details cached on the
/// device, or null when no details are cached (for example after the
/// cache dropped them). The bggId is enough to open the detail.
 final  GameSummary? game;

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmedOnDeviceCopyWith<ConfirmedOnDevice> get copyWith => _$ConfirmedOnDeviceCopyWithImpl<ConfirmedOnDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmedOnDevice&&(identical(other.gtin13, gtin13) || other.gtin13 == gtin13)&&(identical(other.bggId, bggId) || other.bggId == bggId)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.game, game) || other.game == game));
}


@override
int get hashCode {
    return Object.hash(runtimeType,gtin13,bggId,confirmedAt,game);
}

@override
String toString() {
    return 'GameLookupResult.confirmedOnDevice(gtin13: $gtin13, bggId: $bggId, confirmedAt: $confirmedAt, game: $game)';
}


}

/// @nodoc
abstract mixin class $ConfirmedOnDeviceCopyWith<$Res> implements $GameLookupResultCopyWith<$Res> {
  factory $ConfirmedOnDeviceCopyWith(ConfirmedOnDevice value, $Res Function(ConfirmedOnDevice) _then) = _$ConfirmedOnDeviceCopyWithImpl;
@useResult
$Res call({
 String gtin13, int bggId, DateTime confirmedAt, GameSummary? game
});


$GameSummaryCopyWith<$Res>? get game;

}
/// @nodoc
class _$ConfirmedOnDeviceCopyWithImpl<$Res>
    implements $ConfirmedOnDeviceCopyWith<$Res> {
  _$ConfirmedOnDeviceCopyWithImpl(this._self, this._then);

  final ConfirmedOnDevice _self;
  final $Res Function(ConfirmedOnDevice) _then;

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? gtin13 = null,Object? bggId = null,Object? confirmedAt = null,Object? game = freezed,}) {
  return _then(ConfirmedOnDevice(
gtin13: null == gtin13 ? _self.gtin13 : gtin13 // ignore: cast_nullable_to_non_nullable
as String,bggId: null == bggId ? _self.bggId : bggId // ignore: cast_nullable_to_non_nullable
as int,confirmedAt: null == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime,game: freezed == game ? _self.game : game // ignore: cast_nullable_to_non_nullable
as GameSummary?,
  ));
}

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameSummaryCopyWith<$Res>? get game {
    if (_self.game == null) {
    return null;
  }

  return $GameSummaryCopyWith<$Res>(_self.game!, (value) {
    return _then(_self.copyWith(game: value));
  });
}
}

/// @nodoc


class FromBackend extends GameLookupResult {
  const FromBackend(this.lookup): super._();
  

 final  BarcodeLookup lookup;

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FromBackendCopyWith<FromBackend> get copyWith => _$FromBackendCopyWithImpl<FromBackend>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FromBackend&&(identical(other.lookup, lookup) || other.lookup == lookup));
}


@override
int get hashCode {
    return Object.hash(runtimeType,lookup);
}

@override
String toString() {
    return 'GameLookupResult.fromBackend(lookup: $lookup)';
}


}

/// @nodoc
abstract mixin class $FromBackendCopyWith<$Res> implements $GameLookupResultCopyWith<$Res> {
  factory $FromBackendCopyWith(FromBackend value, $Res Function(FromBackend) _then) = _$FromBackendCopyWithImpl;
@useResult
$Res call({
 BarcodeLookup lookup
});


$BarcodeLookupCopyWith<$Res> get lookup;

}
/// @nodoc
class _$FromBackendCopyWithImpl<$Res>
    implements $FromBackendCopyWith<$Res> {
  _$FromBackendCopyWithImpl(this._self, this._then);

  final FromBackend _self;
  final $Res Function(FromBackend) _then;

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lookup = null,}) {
  return _then(FromBackend(
null == lookup ? _self.lookup : lookup // ignore: cast_nullable_to_non_nullable
as BarcodeLookup,
  ));
}

/// Create a copy of GameLookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BarcodeLookupCopyWith<$Res> get lookup {
  
  return $BarcodeLookupCopyWith<$Res>(_self.lookup, (value) {
    return _then(_self.copyWith(lookup: value));
  });
}
}

// dart format on
