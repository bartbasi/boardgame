// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_detail_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GameDetailResponse _$GameDetailResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_GameDetailResponse', json, ($checkedConvert) {
      final val = _GameDetailResponse(
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
        minPlayers: $checkedConvert(
          'minPlayers',
          (v) => _$JsonConverterFromJson<Object, int>(
            v,
            const PositiveIntConverter().fromJson,
          ),
        ),
        maxPlayers: $checkedConvert(
          'maxPlayers',
          (v) => _$JsonConverterFromJson<Object, int>(
            v,
            const PositiveIntConverter().fromJson,
          ),
        ),
        minPlayTimeMinutes: $checkedConvert(
          'minPlayTimeMinutes',
          (v) => _$JsonConverterFromJson<Object, int>(
            v,
            const PositiveIntConverter().fromJson,
          ),
        ),
        maxPlayTimeMinutes: $checkedConvert(
          'maxPlayTimeMinutes',
          (v) => _$JsonConverterFromJson<Object, int>(
            v,
            const PositiveIntConverter().fromJson,
          ),
        ),
        designers: $checkedConvert(
          'designers',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        publishers: $checkedConvert(
          'publishers',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        description: $checkedConvert('description', (v) => v as String?),
        bggUrl: $checkedConvert('bggUrl', (v) => v as String),
        fetchedAt: $checkedConvert(
          'fetchedAt',
          (v) => const UtcDateTimeConverter().fromJson(v as Object),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GameDetailResponseToJson(_GameDetailResponse instance) =>
    <String, dynamic>{
      'bggId': const PositiveIntConverter().toJson(instance.bggId),
      'name': instance.name,
      'yearPublished': _$JsonConverterToJson<Object, int>(
        instance.yearPublished,
        const WholeNumberConverter().toJson,
      ),
      'minPlayers': _$JsonConverterToJson<Object, int>(
        instance.minPlayers,
        const PositiveIntConverter().toJson,
      ),
      'maxPlayers': _$JsonConverterToJson<Object, int>(
        instance.maxPlayers,
        const PositiveIntConverter().toJson,
      ),
      'minPlayTimeMinutes': _$JsonConverterToJson<Object, int>(
        instance.minPlayTimeMinutes,
        const PositiveIntConverter().toJson,
      ),
      'maxPlayTimeMinutes': _$JsonConverterToJson<Object, int>(
        instance.maxPlayTimeMinutes,
        const PositiveIntConverter().toJson,
      ),
      'designers': instance.designers,
      'publishers': instance.publishers,
      'description': instance.description,
      'bggUrl': instance.bggUrl,
      'fetchedAt': const UtcDateTimeConverter().toJson(instance.fetchedAt),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
