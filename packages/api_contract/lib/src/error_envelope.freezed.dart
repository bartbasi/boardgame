// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorEnvelope {

 ApiError get error;
/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorEnvelopeCopyWith<ErrorEnvelope> get copyWith => _$ErrorEnvelopeCopyWithImpl<ErrorEnvelope>(this as ErrorEnvelope, _$identity);

  /// Serializes this ErrorEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ErrorEnvelope;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorEnvelope&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ErrorEnvelope;
  return Object.hash(runtimeType,_this.error);
}

@override
String toString() {
  final _this = this as ErrorEnvelope;
  return 'ErrorEnvelope(error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $ErrorEnvelopeCopyWith<$Res>  {
  factory $ErrorEnvelopeCopyWith(ErrorEnvelope value, $Res Function(ErrorEnvelope) _then) = _$ErrorEnvelopeCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$ErrorEnvelopeCopyWithImpl<$Res>
    implements $ErrorEnvelopeCopyWith<$Res> {
  _$ErrorEnvelopeCopyWithImpl(this._self, this._then);

  final ErrorEnvelope _self;
  final $Res Function(ErrorEnvelope) _then;

/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = null,}) {
  return _then(ErrorEnvelope(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}
/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [ErrorEnvelope].
extension ErrorEnvelopePatterns on ErrorEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ErrorEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ErrorEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ErrorEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _ErrorEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ErrorEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _ErrorEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ApiError error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ErrorEnvelope() when $default != null:
return $default(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ApiError error)  $default,) {final _that = this;
switch (_that) {
case _ErrorEnvelope():
return $default(_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ApiError error)?  $default,) {final _that = this;
switch (_that) {
case _ErrorEnvelope() when $default != null:
return $default(_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ErrorEnvelope implements ErrorEnvelope {
  const _ErrorEnvelope({required this.error});
  factory _ErrorEnvelope.fromJson(Map<String, dynamic> json) => _$ErrorEnvelopeFromJson(json);

@override final  ApiError error;

/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorEnvelopeCopyWith<_ErrorEnvelope> get copyWith => __$ErrorEnvelopeCopyWithImpl<_ErrorEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ErrorEnvelope&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'ErrorEnvelope(error: $error)';
}


}

/// @nodoc
abstract mixin class _$ErrorEnvelopeCopyWith<$Res> implements $ErrorEnvelopeCopyWith<$Res> {
  factory _$ErrorEnvelopeCopyWith(_ErrorEnvelope value, $Res Function(_ErrorEnvelope) _then) = __$ErrorEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 ApiError error
});


@override $ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class __$ErrorEnvelopeCopyWithImpl<$Res>
    implements _$ErrorEnvelopeCopyWith<$Res> {
  __$ErrorEnvelopeCopyWithImpl(this._self, this._then);

  final _ErrorEnvelope _self;
  final $Res Function(_ErrorEnvelope) _then;

/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(_ErrorEnvelope(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of ErrorEnvelope
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$ApiError {

@JsonKey(unknownEnumValue: ErrorCode.unknown) ErrorCode get code; String get message;
/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<ApiError> get copyWith => _$ApiErrorCopyWithImpl<ApiError>(this as ApiError, _$identity);

  /// Serializes this ApiError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ApiError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ApiError;
  return Object.hash(runtimeType,_this.code,_this.message);
}

@override
String toString() {
  final _this = this as ApiError;
  return 'ApiError(code: ${_this.code}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $ApiErrorCopyWith<$Res>  {
  factory $ApiErrorCopyWith(ApiError value, $Res Function(ApiError) _then) = _$ApiErrorCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ErrorCode.unknown) ErrorCode code, String message
});




}
/// @nodoc
class _$ApiErrorCopyWithImpl<$Res>
    implements $ApiErrorCopyWith<$Res> {
  _$ApiErrorCopyWithImpl(this._self, this._then);

  final ApiError _self;
  final $Res Function(ApiError) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = null,}) {
  return _then(ApiError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ErrorCode,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiError].
extension ApiErrorPatterns on ApiError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiError value)  $default,){
final _that = this;
switch (_that) {
case _ApiError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiError value)?  $default,){
final _that = this;
switch (_that) {
case _ApiError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ErrorCode.unknown)  ErrorCode code,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiError() when $default != null:
return $default(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ErrorCode.unknown)  ErrorCode code,  String message)  $default,) {final _that = this;
switch (_that) {
case _ApiError():
return $default(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: ErrorCode.unknown)  ErrorCode code,  String message)?  $default,) {final _that = this;
switch (_that) {
case _ApiError() when $default != null:
return $default(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiError implements ApiError {
  const _ApiError({@JsonKey(unknownEnumValue: ErrorCode.unknown) required this.code, required this.message});
  factory _ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

@override@JsonKey(unknownEnumValue: ErrorCode.unknown) final  ErrorCode code;
@override final  String message;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiErrorCopyWith<_ApiError> get copyWith => __$ApiErrorCopyWithImpl<_ApiError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiErrorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message);
}

@override
String toString() {
    return 'ApiError(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$ApiErrorCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory _$ApiErrorCopyWith(_ApiError value, $Res Function(_ApiError) _then) = __$ApiErrorCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ErrorCode.unknown) ErrorCode code, String message
});




}
/// @nodoc
class __$ApiErrorCopyWithImpl<$Res>
    implements _$ApiErrorCopyWith<$Res> {
  __$ApiErrorCopyWithImpl(this._self, this._then);

  final _ApiError _self;
  final $Res Function(_ApiError) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,}) {
  return _then(_ApiError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ErrorCode,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
