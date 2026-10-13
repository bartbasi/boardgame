// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GameSummary {

/// The game's BoardGameGeek id, a whole number of at least 1.
@PositiveIntConverter() int get bggId;/// The game's primary name, as BGG lists it.
 String get name;/// The year the game was first published, or null when BGG does not
/// give one. Negative values are allowed, so a year before the common
/// era can be represented; the server sends null, never 0, for an
/// unknown year.
@WholeNumberConverter() int? get yearPublished;/// A small cover image URL, or null.
///
/// Always null for now: no cover images are shown until BGG answers how
/// its images may be used (PRD Q5, BGG-42, docs/decisions.md
/// 2026-10-12). The field exists because the screens already handle a
/// missing thumbnail, and filling it later needs no contract change.
 String? get thumbnailUrl;/// The URL of the game's page on BoardGameGeek, built by the server, for
/// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
 String get bggUrl;
/// Create a copy of GameSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameSummaryCopyWith<GameSummary> get copyWith => _$GameSummaryCopyWithImpl<GameSummary>(this as GameSummary, _$identity);

  /// Serializes this GameSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GameSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameSummary&&(identical(other.bggId, _this.bggId) || other.bggId == _this.bggId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.yearPublished, _this.yearPublished) || other.yearPublished == _this.yearPublished)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.bggUrl, _this.bggUrl) || other.bggUrl == _this.bggUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GameSummary;
  return Object.hash(runtimeType,_this.bggId,_this.name,_this.yearPublished,_this.thumbnailUrl,_this.bggUrl);
}

@override
String toString() {
  final _this = this as GameSummary;
  return 'GameSummary(bggId: ${_this.bggId}, name: ${_this.name}, yearPublished: ${_this.yearPublished}, thumbnailUrl: ${_this.thumbnailUrl}, bggUrl: ${_this.bggUrl})';
}


}

/// @nodoc
abstract mixin class $GameSummaryCopyWith<$Res>  {
  factory $GameSummaryCopyWith(GameSummary value, $Res Function(GameSummary) _then) = _$GameSummaryCopyWithImpl;
@useResult
$Res call({
@PositiveIntConverter() int bggId, String name,@WholeNumberConverter() int? yearPublished, String? thumbnailUrl, String bggUrl
});




}
/// @nodoc
class _$GameSummaryCopyWithImpl<$Res>
    implements $GameSummaryCopyWith<$Res> {
  _$GameSummaryCopyWithImpl(this._self, this._then);

  final GameSummary _self;
  final $Res Function(GameSummary) _then;

/// Create a copy of GameSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? thumbnailUrl = freezed,Object? bggUrl = null,}) {
  return _then(GameSummary(
bggId: null == bggId ? _self.bggId : bggId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,yearPublished: freezed == yearPublished ? _self.yearPublished : yearPublished // ignore: cast_nullable_to_non_nullable
as int?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,bggUrl: null == bggUrl ? _self.bggUrl : bggUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GameSummary].
extension GameSummaryPatterns on GameSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameSummary value)  $default,){
final _that = this;
switch (_that) {
case _GameSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameSummary value)?  $default,){
final _that = this;
switch (_that) {
case _GameSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished,  String? thumbnailUrl,  String bggUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameSummary() when $default != null:
return $default(_that.bggId,_that.name,_that.yearPublished,_that.thumbnailUrl,_that.bggUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished,  String? thumbnailUrl,  String bggUrl)  $default,) {final _that = this;
switch (_that) {
case _GameSummary():
return $default(_that.bggId,_that.name,_that.yearPublished,_that.thumbnailUrl,_that.bggUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished,  String? thumbnailUrl,  String bggUrl)?  $default,) {final _that = this;
switch (_that) {
case _GameSummary() when $default != null:
return $default(_that.bggId,_that.name,_that.yearPublished,_that.thumbnailUrl,_that.bggUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GameSummary implements GameSummary {
  const _GameSummary({@PositiveIntConverter() required this.bggId, required this.name, @WholeNumberConverter() this.yearPublished, this.thumbnailUrl, required this.bggUrl});
  factory _GameSummary.fromJson(Map<String, dynamic> json) => _$GameSummaryFromJson(json);

/// The game's BoardGameGeek id, a whole number of at least 1.
@override@PositiveIntConverter() final  int bggId;
/// The game's primary name, as BGG lists it.
@override final  String name;
/// The year the game was first published, or null when BGG does not
/// give one. Negative values are allowed, so a year before the common
/// era can be represented; the server sends null, never 0, for an
/// unknown year.
@override@WholeNumberConverter() final  int? yearPublished;
/// A small cover image URL, or null.
///
/// Always null for now: no cover images are shown until BGG answers how
/// its images may be used (PRD Q5, BGG-42, docs/decisions.md
/// 2026-10-12). The field exists because the screens already handle a
/// missing thumbnail, and filling it later needs no contract change.
@override final  String? thumbnailUrl;
/// The URL of the game's page on BoardGameGeek, built by the server, for
/// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
@override final  String bggUrl;

/// Create a copy of GameSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameSummaryCopyWith<_GameSummary> get copyWith => __$GameSummaryCopyWithImpl<_GameSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GameSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameSummary&&(identical(other.bggId, bggId) || other.bggId == bggId)&&(identical(other.name, name) || other.name == name)&&(identical(other.yearPublished, yearPublished) || other.yearPublished == yearPublished)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.bggUrl, bggUrl) || other.bggUrl == bggUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bggId,name,yearPublished,thumbnailUrl,bggUrl);
}

@override
String toString() {
    return 'GameSummary(bggId: $bggId, name: $name, yearPublished: $yearPublished, thumbnailUrl: $thumbnailUrl, bggUrl: $bggUrl)';
}


}

/// @nodoc
abstract mixin class _$GameSummaryCopyWith<$Res> implements $GameSummaryCopyWith<$Res> {
  factory _$GameSummaryCopyWith(_GameSummary value, $Res Function(_GameSummary) _then) = __$GameSummaryCopyWithImpl;
@override @useResult
$Res call({
@PositiveIntConverter() int bggId, String name,@WholeNumberConverter() int? yearPublished, String? thumbnailUrl, String bggUrl
});




}
/// @nodoc
class __$GameSummaryCopyWithImpl<$Res>
    implements _$GameSummaryCopyWith<$Res> {
  __$GameSummaryCopyWithImpl(this._self, this._then);

  final _GameSummary _self;
  final $Res Function(_GameSummary) _then;

/// Create a copy of GameSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? thumbnailUrl = freezed,Object? bggUrl = null,}) {
  return _then(_GameSummary(
bggId: null == bggId ? _self.bggId : bggId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,yearPublished: freezed == yearPublished ? _self.yearPublished : yearPublished // ignore: cast_nullable_to_non_nullable
as int?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,bggUrl: null == bggUrl ? _self.bggUrl : bggUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
