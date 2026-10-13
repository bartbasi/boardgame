// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_detail_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GameDetailResponse {

/// The game's BoardGameGeek id, a whole number of at least 1.
@PositiveIntConverter() int get bggId;/// The game's primary name, as BGG lists it.
 String get name;/// The year the game was first published, or null. Negative values are
/// allowed; the server sends null, never 0, for an unknown year.
@WholeNumberConverter() int? get yearPublished;/// The smallest player count, at least 1, or null.
@PositiveIntConverter() int? get minPlayers;/// The largest player count, at least 1, or null.
@PositiveIntConverter() int? get maxPlayers;/// The shortest play time in minutes, at least 1, or null.
@PositiveIntConverter() int? get minPlayTimeMinutes;/// The longest play time in minutes, at least 1, or null.
@PositiveIntConverter() int? get maxPlayTimeMinutes;/// Designer names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
 List<String> get designers;/// Publisher names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
 List<String> get publishers;/// The description as plain text: line breaks are `\n`, and it holds
/// no HTML markup or character entities (the server decodes them).
/// Null when BGG gives no description.
 String? get description;/// The URL of the game's page on BoardGameGeek, built by the server, for
/// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
 String get bggUrl;/// When the server fetched this data from BGG, in UTC. A cached answer
/// keeps its original time.
@UtcDateTimeConverter() DateTime get fetchedAt;
/// Create a copy of GameDetailResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameDetailResponseCopyWith<GameDetailResponse> get copyWith => _$GameDetailResponseCopyWithImpl<GameDetailResponse>(this as GameDetailResponse, _$identity);

  /// Serializes this GameDetailResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GameDetailResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameDetailResponse&&(identical(other.bggId, _this.bggId) || other.bggId == _this.bggId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.yearPublished, _this.yearPublished) || other.yearPublished == _this.yearPublished)&&(identical(other.minPlayers, _this.minPlayers) || other.minPlayers == _this.minPlayers)&&(identical(other.maxPlayers, _this.maxPlayers) || other.maxPlayers == _this.maxPlayers)&&(identical(other.minPlayTimeMinutes, _this.minPlayTimeMinutes) || other.minPlayTimeMinutes == _this.minPlayTimeMinutes)&&(identical(other.maxPlayTimeMinutes, _this.maxPlayTimeMinutes) || other.maxPlayTimeMinutes == _this.maxPlayTimeMinutes)&&const DeepCollectionEquality().equals(other.designers, _this.designers)&&const DeepCollectionEquality().equals(other.publishers, _this.publishers)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.bggUrl, _this.bggUrl) || other.bggUrl == _this.bggUrl)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GameDetailResponse;
  return Object.hash(runtimeType,_this.bggId,_this.name,_this.yearPublished,_this.minPlayers,_this.maxPlayers,_this.minPlayTimeMinutes,_this.maxPlayTimeMinutes,const DeepCollectionEquality().hash(_this.designers),const DeepCollectionEquality().hash(_this.publishers),_this.description,_this.bggUrl,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as GameDetailResponse;
  return 'GameDetailResponse(bggId: ${_this.bggId}, name: ${_this.name}, yearPublished: ${_this.yearPublished}, minPlayers: ${_this.minPlayers}, maxPlayers: ${_this.maxPlayers}, minPlayTimeMinutes: ${_this.minPlayTimeMinutes}, maxPlayTimeMinutes: ${_this.maxPlayTimeMinutes}, designers: ${_this.designers}, publishers: ${_this.publishers}, description: ${_this.description}, bggUrl: ${_this.bggUrl}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $GameDetailResponseCopyWith<$Res>  {
  factory $GameDetailResponseCopyWith(GameDetailResponse value, $Res Function(GameDetailResponse) _then) = _$GameDetailResponseCopyWithImpl;
@useResult
$Res call({
@PositiveIntConverter() int bggId, String name,@WholeNumberConverter() int? yearPublished,@PositiveIntConverter() int? minPlayers,@PositiveIntConverter() int? maxPlayers,@PositiveIntConverter() int? minPlayTimeMinutes,@PositiveIntConverter() int? maxPlayTimeMinutes, List<String> designers, List<String> publishers, String? description, String bggUrl,@UtcDateTimeConverter() DateTime fetchedAt
});




}
/// @nodoc
class _$GameDetailResponseCopyWithImpl<$Res>
    implements $GameDetailResponseCopyWith<$Res> {
  _$GameDetailResponseCopyWithImpl(this._self, this._then);

  final GameDetailResponse _self;
  final $Res Function(GameDetailResponse) _then;

/// Create a copy of GameDetailResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? minPlayers = freezed,Object? maxPlayers = freezed,Object? minPlayTimeMinutes = freezed,Object? maxPlayTimeMinutes = freezed,Object? designers = null,Object? publishers = null,Object? description = freezed,Object? bggUrl = null,Object? fetchedAt = null,}) {
  return _then(GameDetailResponse(
bggId: null == bggId ? _self.bggId : bggId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,yearPublished: freezed == yearPublished ? _self.yearPublished : yearPublished // ignore: cast_nullable_to_non_nullable
as int?,minPlayers: freezed == minPlayers ? _self.minPlayers : minPlayers // ignore: cast_nullable_to_non_nullable
as int?,maxPlayers: freezed == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int?,minPlayTimeMinutes: freezed == minPlayTimeMinutes ? _self.minPlayTimeMinutes : minPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,maxPlayTimeMinutes: freezed == maxPlayTimeMinutes ? _self.maxPlayTimeMinutes : maxPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,designers: null == designers ? _self.designers : designers // ignore: cast_nullable_to_non_nullable
as List<String>,publishers: null == publishers ? _self.publishers : publishers // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,bggUrl: null == bggUrl ? _self.bggUrl : bggUrl // ignore: cast_nullable_to_non_nullable
as String,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [GameDetailResponse].
extension GameDetailResponsePatterns on GameDetailResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameDetailResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameDetailResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameDetailResponse value)  $default,){
final _that = this;
switch (_that) {
case _GameDetailResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameDetailResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GameDetailResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished, @PositiveIntConverter()  int? minPlayers, @PositiveIntConverter()  int? maxPlayers, @PositiveIntConverter()  int? minPlayTimeMinutes, @PositiveIntConverter()  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl, @UtcDateTimeConverter()  DateTime fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameDetailResponse() when $default != null:
return $default(_that.bggId,_that.name,_that.yearPublished,_that.minPlayers,_that.maxPlayers,_that.minPlayTimeMinutes,_that.maxPlayTimeMinutes,_that.designers,_that.publishers,_that.description,_that.bggUrl,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished, @PositiveIntConverter()  int? minPlayers, @PositiveIntConverter()  int? maxPlayers, @PositiveIntConverter()  int? minPlayTimeMinutes, @PositiveIntConverter()  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl, @UtcDateTimeConverter()  DateTime fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _GameDetailResponse():
return $default(_that.bggId,_that.name,_that.yearPublished,_that.minPlayers,_that.maxPlayers,_that.minPlayTimeMinutes,_that.maxPlayTimeMinutes,_that.designers,_that.publishers,_that.description,_that.bggUrl,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@PositiveIntConverter()  int bggId,  String name, @WholeNumberConverter()  int? yearPublished, @PositiveIntConverter()  int? minPlayers, @PositiveIntConverter()  int? maxPlayers, @PositiveIntConverter()  int? minPlayTimeMinutes, @PositiveIntConverter()  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl, @UtcDateTimeConverter()  DateTime fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _GameDetailResponse() when $default != null:
return $default(_that.bggId,_that.name,_that.yearPublished,_that.minPlayers,_that.maxPlayers,_that.minPlayTimeMinutes,_that.maxPlayTimeMinutes,_that.designers,_that.publishers,_that.description,_that.bggUrl,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GameDetailResponse implements GameDetailResponse {
  const _GameDetailResponse({@PositiveIntConverter() required this.bggId, required this.name, @WholeNumberConverter() this.yearPublished, @PositiveIntConverter() this.minPlayers, @PositiveIntConverter() this.maxPlayers, @PositiveIntConverter() this.minPlayTimeMinutes, @PositiveIntConverter() this.maxPlayTimeMinutes,  List<String> designers = const <String>[],  List<String> publishers = const <String>[], this.description, required this.bggUrl, @UtcDateTimeConverter() required this.fetchedAt}): _designers = designers,_publishers = publishers;
  factory _GameDetailResponse.fromJson(Map<String, dynamic> json) => _$GameDetailResponseFromJson(json);

/// The game's BoardGameGeek id, a whole number of at least 1.
@override@PositiveIntConverter() final  int bggId;
/// The game's primary name, as BGG lists it.
@override final  String name;
/// The year the game was first published, or null. Negative values are
/// allowed; the server sends null, never 0, for an unknown year.
@override@WholeNumberConverter() final  int? yearPublished;
/// The smallest player count, at least 1, or null.
@override@PositiveIntConverter() final  int? minPlayers;
/// The largest player count, at least 1, or null.
@override@PositiveIntConverter() final  int? maxPlayers;
/// The shortest play time in minutes, at least 1, or null.
@override@PositiveIntConverter() final  int? minPlayTimeMinutes;
/// The longest play time in minutes, at least 1, or null.
@override@PositiveIntConverter() final  int? maxPlayTimeMinutes;
/// Designer names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
 final  List<String> _designers;
/// Designer names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
@override@JsonKey() List<String> get designers {
  if (_designers is EqualUnmodifiableListView) return _designers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_designers);
}

/// Publisher names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
 final  List<String> _publishers;
/// Publisher names in BGG's order. Empty when BGG lists none; a missing
/// or null value decodes as empty.
@override@JsonKey() List<String> get publishers {
  if (_publishers is EqualUnmodifiableListView) return _publishers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_publishers);
}

/// The description as plain text: line breaks are `\n`, and it holds
/// no HTML markup or character entities (the server decodes them).
/// Null when BGG gives no description.
@override final  String? description;
/// The URL of the game's page on BoardGameGeek, built by the server, for
/// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
@override final  String bggUrl;
/// When the server fetched this data from BGG, in UTC. A cached answer
/// keeps its original time.
@override@UtcDateTimeConverter() final  DateTime fetchedAt;

/// Create a copy of GameDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameDetailResponseCopyWith<_GameDetailResponse> get copyWith => __$GameDetailResponseCopyWithImpl<_GameDetailResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GameDetailResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameDetailResponse&&(identical(other.bggId, bggId) || other.bggId == bggId)&&(identical(other.name, name) || other.name == name)&&(identical(other.yearPublished, yearPublished) || other.yearPublished == yearPublished)&&(identical(other.minPlayers, minPlayers) || other.minPlayers == minPlayers)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&(identical(other.minPlayTimeMinutes, minPlayTimeMinutes) || other.minPlayTimeMinutes == minPlayTimeMinutes)&&(identical(other.maxPlayTimeMinutes, maxPlayTimeMinutes) || other.maxPlayTimeMinutes == maxPlayTimeMinutes)&&const DeepCollectionEquality().equals(other.designers, _designers)&&const DeepCollectionEquality().equals(other.publishers, _publishers)&&(identical(other.description, description) || other.description == description)&&(identical(other.bggUrl, bggUrl) || other.bggUrl == bggUrl)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bggId,name,yearPublished,minPlayers,maxPlayers,minPlayTimeMinutes,maxPlayTimeMinutes,const DeepCollectionEquality().hash(_designers),const DeepCollectionEquality().hash(_publishers),description,bggUrl,fetchedAt);
}

@override
String toString() {
    return 'GameDetailResponse(bggId: $bggId, name: $name, yearPublished: $yearPublished, minPlayers: $minPlayers, maxPlayers: $maxPlayers, minPlayTimeMinutes: $minPlayTimeMinutes, maxPlayTimeMinutes: $maxPlayTimeMinutes, designers: $designers, publishers: $publishers, description: $description, bggUrl: $bggUrl, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$GameDetailResponseCopyWith<$Res> implements $GameDetailResponseCopyWith<$Res> {
  factory _$GameDetailResponseCopyWith(_GameDetailResponse value, $Res Function(_GameDetailResponse) _then) = __$GameDetailResponseCopyWithImpl;
@override @useResult
$Res call({
@PositiveIntConverter() int bggId, String name,@WholeNumberConverter() int? yearPublished,@PositiveIntConverter() int? minPlayers,@PositiveIntConverter() int? maxPlayers,@PositiveIntConverter() int? minPlayTimeMinutes,@PositiveIntConverter() int? maxPlayTimeMinutes, List<String> designers, List<String> publishers, String? description, String bggUrl,@UtcDateTimeConverter() DateTime fetchedAt
});




}
/// @nodoc
class __$GameDetailResponseCopyWithImpl<$Res>
    implements _$GameDetailResponseCopyWith<$Res> {
  __$GameDetailResponseCopyWithImpl(this._self, this._then);

  final _GameDetailResponse _self;
  final $Res Function(_GameDetailResponse) _then;

/// Create a copy of GameDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? minPlayers = freezed,Object? maxPlayers = freezed,Object? minPlayTimeMinutes = freezed,Object? maxPlayTimeMinutes = freezed,Object? designers = null,Object? publishers = null,Object? description = freezed,Object? bggUrl = null,Object? fetchedAt = null,}) {
  return _then(_GameDetailResponse(
bggId: null == bggId ? _self.bggId : bggId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,yearPublished: freezed == yearPublished ? _self.yearPublished : yearPublished // ignore: cast_nullable_to_non_nullable
as int?,minPlayers: freezed == minPlayers ? _self.minPlayers : minPlayers // ignore: cast_nullable_to_non_nullable
as int?,maxPlayers: freezed == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int?,minPlayTimeMinutes: freezed == minPlayTimeMinutes ? _self.minPlayTimeMinutes : minPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,maxPlayTimeMinutes: freezed == maxPlayTimeMinutes ? _self.maxPlayTimeMinutes : maxPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,designers: null == designers ? _self._designers : designers // ignore: cast_nullable_to_non_nullable
as List<String>,publishers: null == publishers ? _self._publishers : publishers // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,bggUrl: null == bggUrl ? _self.bggUrl : bggUrl // ignore: cast_nullable_to_non_nullable
as String,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
