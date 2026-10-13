// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LookupResponse _$LookupResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_LookupResponse', json, ($checkedConvert) {
      final val = _LookupResponse(
        code: $checkedConvert(
          'code',
          (v) => const Gtin13Converter().fromJson(v as Object),
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$LookupStatusEnumMap,
            v,
            unknownValue: LookupStatus.unknown,
          ),
        ),
        games: $checkedConvert(
          'games',
          (v) => (v as List<dynamic>)
              .map((e) => GameSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LookupResponseToJson(_LookupResponse instance) =>
    <String, dynamic>{
      'code': const Gtin13Converter().toJson(instance.code),
      'status': _$LookupStatusEnumMap[instance.status]!,
      'games': instance.games.map((e) => e.toJson()).toList(),
    };

const _$LookupStatusEnumMap = {
  LookupStatus.matched: 'matched',
  LookupStatus.candidates: 'candidates',
  LookupStatus.none: 'none',
  LookupStatus.unavailable: 'unavailable',
  LookupStatus.unknown: 'unknown',
};
