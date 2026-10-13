// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GameSummary _$GameSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_GameSummary', json, ($checkedConvert) {
      final val = _GameSummary(
        bggId: $checkedConvert(
          'bggId',
          (v) => const PositiveIntConverter().fromJson(v as Object),
        ),
        name: $checkedConvert('name', (v) => v as String),
        yearPublished: $checkedConvert(
          'yearPublished',
          (v) => _$JsonConverterFromJson<Object, int>(
            v,
            const WholeNumberConverter().fromJson,
          ),
        ),
        bggUrl: $checkedConvert('bggUrl', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GameSummaryToJson(_GameSummary instance) =>
    <String, dynamic>{
      'bggId': const PositiveIntConverter().toJson(instance.bggId),
      'name': instance.name,
      'yearPublished': _$JsonConverterToJson<Object, int>(
        instance.yearPublished,
        const WholeNumberConverter().toJson,
      ),
      'bggUrl': instance.bggUrl,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
