// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ErrorEnvelope _$ErrorEnvelopeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ErrorEnvelope', json, ($checkedConvert) {
      final val = _ErrorEnvelope(
        error: $checkedConvert(
          'error',
          (v) => ApiError.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ErrorEnvelopeToJson(_ErrorEnvelope instance) =>
    <String, dynamic>{'error': instance.error.toJson()};

_ApiError _$ApiErrorFromJson(Map<String, dynamic> json) => $checkedCreate(
  '_ApiError',
  json,
  ($checkedConvert) {
    final val = _ApiError(
      code: $checkedConvert(
        'code',
        (v) =>
            $enumDecode(_$ErrorCodeEnumMap, v, unknownValue: ErrorCode.unknown),
      ),
      message: $checkedConvert('message', (v) => v as String),
    );
    return val;
  },
);

Map<String, dynamic> _$ApiErrorToJson(_ApiError instance) => <String, dynamic>{
  'code': _$ErrorCodeEnumMap[instance.code]!,
  'message': instance.message,
};

const _$ErrorCodeEnumMap = {
  ErrorCode.invalidBarcode: 'invalid_barcode',
  ErrorCode.invalidQuery: 'invalid_query',
  ErrorCode.invalidBggId: 'invalid_bgg_id',
  ErrorCode.notFound: 'not_found',
  ErrorCode.rateLimited: 'rate_limited',
  ErrorCode.upstreamUnavailable: 'upstream_unavailable',
  ErrorCode.internalError: 'internal_error',
  ErrorCode.unknown: 'unknown',
};
