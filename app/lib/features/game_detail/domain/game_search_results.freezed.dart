// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_search_results.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GameSearchResults {

/// The query as the backend normalized it (for example trimmed), which
/// may differ from the text the user typed.
 String get query;/// The results in the backend's ranking order, exact name matches first.
 List<GameSummary> get games;
/// Create a copy of GameSearchResults
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameSearchResultsCopyWith<GameSearchResults> get copyWith => _$GameSearchResultsCopyWithImpl<GameSearchResults>(this as GameSearchResults, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GameSearchResults;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameSearchResults&&(identical(other.query, _this.query) || other.query == _this.query)&&const DeepCollectionEquality().equals(other.games, _this.games));
}


@override
int get hashCode {
  final _this = this as GameSearchResults;
  return Object.hash(runtimeType,_this.query,const DeepCollectionEquality().hash(_this.games));
}

@override
String toString() {
  final _this = this as GameSearchResults;
  return 'GameSearchResults(query: ${_this.query}, games: ${_this.games})';
}


}

/// @nodoc
abstract mixin class $GameSearchResultsCopyWith<$Res>  {
  factory $GameSearchResultsCopyWith(GameSearchResults value, $Res Function(GameSearchResults) _then) = _$GameSearchResultsCopyWithImpl;
@useResult
$Res call({
 String query, List<GameSummary> games
});




}
/// @nodoc
class _$GameSearchResultsCopyWithImpl<$Res>
    implements $GameSearchResultsCopyWith<$Res> {
  _$GameSearchResultsCopyWithImpl(this._self, this._then);

  final GameSearchResults _self;
  final $Res Function(GameSearchResults) _then;

/// Create a copy of GameSearchResults
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? games = null,}) {
  return _then(GameSearchResults(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,games: null == games ? _self.games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [GameSearchResults].
extension GameSearchResultsPatterns on GameSearchResults {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameSearchResults value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameSearchResults() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameSearchResults value)  $default,){
final _that = this;
switch (_that) {
case _GameSearchResults():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameSearchResults value)?  $default,){
final _that = this;
switch (_that) {
case _GameSearchResults() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  List<GameSummary> games)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameSearchResults() when $default != null:
return $default(_that.query,_that.games);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  List<GameSummary> games)  $default,) {final _that = this;
switch (_that) {
case _GameSearchResults():
return $default(_that.query,_that.games);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  List<GameSummary> games)?  $default,) {final _that = this;
switch (_that) {
case _GameSearchResults() when $default != null:
return $default(_that.query,_that.games);case _:
  return null;

}
}

}

/// @nodoc


class _GameSearchResults implements GameSearchResults {
  const _GameSearchResults({required this.query, required  List<GameSummary> games}): _games = games;
  

/// The query as the backend normalized it (for example trimmed), which
/// may differ from the text the user typed.
@override final  String query;
/// The results in the backend's ranking order, exact name matches first.
 final  List<GameSummary> _games;
/// The results in the backend's ranking order, exact name matches first.
@override List<GameSummary> get games {
  if (_games is EqualUnmodifiableListView) return _games;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_games);
}


/// Create a copy of GameSearchResults
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameSearchResultsCopyWith<_GameSearchResults> get copyWith => __$GameSearchResultsCopyWithImpl<_GameSearchResults>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameSearchResults&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other.games, _games));
}


@override
int get hashCode {
    return Object.hash(runtimeType,query,const DeepCollectionEquality().hash(_games));
}

@override
String toString() {
    return 'GameSearchResults(query: $query, games: $games)';
}


}

/// @nodoc
abstract mixin class _$GameSearchResultsCopyWith<$Res> implements $GameSearchResultsCopyWith<$Res> {
  factory _$GameSearchResultsCopyWith(_GameSearchResults value, $Res Function(_GameSearchResults) _then) = __$GameSearchResultsCopyWithImpl;
@override @useResult
$Res call({
 String query, List<GameSummary> games
});




}
/// @nodoc
class __$GameSearchResultsCopyWithImpl<$Res>
    implements _$GameSearchResultsCopyWith<$Res> {
  __$GameSearchResultsCopyWithImpl(this._self, this._then);

  final _GameSearchResults _self;
  final $Res Function(_GameSearchResults) _then;

/// Create a copy of GameSearchResults
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? games = null,}) {
  return _then(_GameSearchResults(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,games: null == games ? _self._games : games // ignore: cast_nullable_to_non_nullable
as List<GameSummary>,
  ));
}


}

// dart format on
