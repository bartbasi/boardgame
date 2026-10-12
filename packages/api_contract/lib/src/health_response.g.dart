// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthResponse _$HealthResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HealthResponse', json, ($checkedConvert) {
      final val = _HealthResponse(
        status: $checkedConvert('status', (v) => v as String),
        version: $checkedConvert('version', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) =>
    <String, dynamic>{'status': instance.status, 'version': instance.version};
