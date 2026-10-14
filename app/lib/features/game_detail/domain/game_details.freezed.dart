// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GameDetails {

/// The game's BoardGameGeek id, at least 1.
 int get bggId;/// The game's primary name, as BGG lists it.
 String get name;/// The year the game was first published, or null when unknown.
 int? get yearPublished;/// The smallest player count, or null when unknown.
 int? get minPlayers;/// The largest player count, or null when unknown.
 int? get maxPlayers;/// The shortest play time in minutes, or null when unknown.
 int? get minPlayTimeMinutes;/// The longest play time in minutes, or null when unknown.
 int? get maxPlayTimeMinutes;/// Designer names in BGG's order; empty when BGG lists none.
 List<String> get designers;/// Publisher names in BGG's order; empty when BGG lists none.
 List<String> get publishers;/// The description as plain text with `\n` line breaks, or null.
 String? get description;/// The game's BoardGameGeek page, as the backend sent it.
 String get bggUrl;/// When the backend fetched this data from BGG, in UTC. Used for the
/// "Last updated" label and cache freshness.
 DateTime get fetchedAt;
/// Create a copy of GameDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameDetailsCopyWith<GameDetails> get copyWith => _$GameDetailsCopyWithImpl<GameDetails>(this as GameDetails, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GameDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameDetails&&(identical(other.bggId, _this.bggId) || other.bggId == _this.bggId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.yearPublished, _this.yearPublished) || other.yearPublished == _this.yearPublished)&&(identical(other.minPlayers, _this.minPlayers) || other.minPlayers == _this.minPlayers)&&(identical(other.maxPlayers, _this.maxPlayers) || other.maxPlayers == _this.maxPlayers)&&(identical(other.minPlayTimeMinutes, _this.minPlayTimeMinutes) || other.minPlayTimeMinutes == _this.minPlayTimeMinutes)&&(identical(other.maxPlayTimeMinutes, _this.maxPlayTimeMinutes) || other.maxPlayTimeMinutes == _this.maxPlayTimeMinutes)&&const DeepCollectionEquality().equals(other.designers, _this.designers)&&const DeepCollectionEquality().equals(other.publishers, _this.publishers)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.bggUrl, _this.bggUrl) || other.bggUrl == _this.bggUrl)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}


@override
int get hashCode {
  final _this = this as GameDetails;
  return Object.hash(runtimeType,_this.bggId,_this.name,_this.yearPublished,_this.minPlayers,_this.maxPlayers,_this.minPlayTimeMinutes,_this.maxPlayTimeMinutes,const DeepCollectionEquality().hash(_this.designers),const DeepCollectionEquality().hash(_this.publishers),_this.description,_this.bggUrl,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as GameDetails;
  return 'GameDetails(bggId: ${_this.bggId}, name: ${_this.name}, yearPublished: ${_this.yearPublished}, minPlayers: ${_this.minPlayers}, maxPlayers: ${_this.maxPlayers}, minPlayTimeMinutes: ${_this.minPlayTimeMinutes}, maxPlayTimeMinutes: ${_this.maxPlayTimeMinutes}, designers: ${_this.designers}, publishers: ${_this.publishers}, description: ${_this.description}, bggUrl: ${_this.bggUrl}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $GameDetailsCopyWith<$Res>  {
  factory $GameDetailsCopyWith(GameDetails value, $Res Function(GameDetails) _then) = _$GameDetailsCopyWithImpl;
@useResult
$Res call({
 int bggId, String name, int? yearPublished, int? minPlayers, int? maxPlayers, int? minPlayTimeMinutes, int? maxPlayTimeMinutes, List<String> designers, List<String> publishers, String? description, String bggUrl, DateTime fetchedAt
});




}
/// @nodoc
class _$GameDetailsCopyWithImpl<$Res>
    implements $GameDetailsCopyWith<$Res> {
  _$GameDetailsCopyWithImpl(this._self, this._then);

  final GameDetails _self;
  final $Res Function(GameDetails) _then;

/// Create a copy of GameDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? minPlayers = freezed,Object? maxPlayers = freezed,Object? minPlayTimeMinutes = freezed,Object? maxPlayTimeMinutes = freezed,Object? designers = null,Object? publishers = null,Object? description = freezed,Object? bggUrl = null,Object? fetchedAt = null,}) {
  return _then(GameDetails(
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


/// Adds pattern-matching-related methods to [GameDetails].
extension GameDetailsPatterns on GameDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameDetails value)  $default,){
final _that = this;
switch (_that) {
case _GameDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameDetails value)?  $default,){
final _that = this;
switch (_that) {
case _GameDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int bggId,  String name,  int? yearPublished,  int? minPlayers,  int? maxPlayers,  int? minPlayTimeMinutes,  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl,  DateTime fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameDetails() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int bggId,  String name,  int? yearPublished,  int? minPlayers,  int? maxPlayers,  int? minPlayTimeMinutes,  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl,  DateTime fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _GameDetails():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int bggId,  String name,  int? yearPublished,  int? minPlayers,  int? maxPlayers,  int? minPlayTimeMinutes,  int? maxPlayTimeMinutes,  List<String> designers,  List<String> publishers,  String? description,  String bggUrl,  DateTime fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _GameDetails() when $default != null:
return $default(_that.bggId,_that.name,_that.yearPublished,_that.minPlayers,_that.maxPlayers,_that.minPlayTimeMinutes,_that.maxPlayTimeMinutes,_that.designers,_that.publishers,_that.description,_that.bggUrl,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc


class _GameDetails implements GameDetails {
  const _GameDetails({required this.bggId, required this.name, this.yearPublished, this.minPlayers, this.maxPlayers, this.minPlayTimeMinutes, this.maxPlayTimeMinutes, required  List<String> designers, required  List<String> publishers, this.description, required this.bggUrl, required this.fetchedAt}): _designers = designers,_publishers = publishers;
  

/// The game's BoardGameGeek id, at least 1.
@override final  int bggId;
/// The game's primary name, as BGG lists it.
@override final  String name;
/// The year the game was first published, or null when unknown.
@override final  int? yearPublished;
/// The smallest player count, or null when unknown.
@override final  int? minPlayers;
/// The largest player count, or null when unknown.
@override final  int? maxPlayers;
/// The shortest play time in minutes, or null when unknown.
@override final  int? minPlayTimeMinutes;
/// The longest play time in minutes, or null when unknown.
@override final  int? maxPlayTimeMinutes;
/// Designer names in BGG's order; empty when BGG lists none.
 final  List<String> _designers;
/// Designer names in BGG's order; empty when BGG lists none.
@override List<String> get designers {
  if (_designers is EqualUnmodifiableListView) return _designers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_designers);
}

/// Publisher names in BGG's order; empty when BGG lists none.
 final  List<String> _publishers;
/// Publisher names in BGG's order; empty when BGG lists none.
@override List<String> get publishers {
  if (_publishers is EqualUnmodifiableListView) return _publishers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_publishers);
}

/// The description as plain text with `\n` line breaks, or null.
@override final  String? description;
/// The game's BoardGameGeek page, as the backend sent it.
@override final  String bggUrl;
/// When the backend fetched this data from BGG, in UTC. Used for the
/// "Last updated" label and cache freshness.
@override final  DateTime fetchedAt;

/// Create a copy of GameDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameDetailsCopyWith<_GameDetails> get copyWith => __$GameDetailsCopyWithImpl<_GameDetails>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameDetails&&(identical(other.bggId, bggId) || other.bggId == bggId)&&(identical(other.name, name) || other.name == name)&&(identical(other.yearPublished, yearPublished) || other.yearPublished == yearPublished)&&(identical(other.minPlayers, minPlayers) || other.minPlayers == minPlayers)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&(identical(other.minPlayTimeMinutes, minPlayTimeMinutes) || other.minPlayTimeMinutes == minPlayTimeMinutes)&&(identical(other.maxPlayTimeMinutes, maxPlayTimeMinutes) || other.maxPlayTimeMinutes == maxPlayTimeMinutes)&&const DeepCollectionEquality().equals(other.designers, _designers)&&const DeepCollectionEquality().equals(other.publishers, _publishers)&&(identical(other.description, description) || other.description == description)&&(identical(other.bggUrl, bggUrl) || other.bggUrl == bggUrl)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,bggId,name,yearPublished,minPlayers,maxPlayers,minPlayTimeMinutes,maxPlayTimeMinutes,const DeepCollectionEquality().hash(_designers),const DeepCollectionEquality().hash(_publishers),description,bggUrl,fetchedAt);
}

@override
String toString() {
    return 'GameDetails(bggId: $bggId, name: $name, yearPublished: $yearPublished, minPlayers: $minPlayers, maxPlayers: $maxPlayers, minPlayTimeMinutes: $minPlayTimeMinutes, maxPlayTimeMinutes: $maxPlayTimeMinutes, designers: $designers, publishers: $publishers, description: $description, bggUrl: $bggUrl, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$GameDetailsCopyWith<$Res> implements $GameDetailsCopyWith<$Res> {
  factory _$GameDetailsCopyWith(_GameDetails value, $Res Function(_GameDetails) _then) = __$GameDetailsCopyWithImpl;
@override @useResult
$Res call({
 int bggId, String name, int? yearPublished, int? minPlayers, int? maxPlayers, int? minPlayTimeMinutes, int? maxPlayTimeMinutes, List<String> designers, List<String> publishers, String? description, String bggUrl, DateTime fetchedAt
});




}
/// @nodoc
class __$GameDetailsCopyWithImpl<$Res>
    implements _$GameDetailsCopyWith<$Res> {
  __$GameDetailsCopyWithImpl(this._self, this._then);

  final _GameDetails _self;
  final $Res Function(_GameDetails) _then;

/// Create a copy of GameDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bggId = null,Object? name = null,Object? yearPublished = freezed,Object? minPlayers = freezed,Object? maxPlayers = freezed,Object? minPlayTimeMinutes = freezed,Object? maxPlayTimeMinutes = freezed,Object? designers = null,Object? publishers = null,Object? description = freezed,Object? bggUrl = null,Object? fetchedAt = null,}) {
  return _then(_GameDetails(
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
