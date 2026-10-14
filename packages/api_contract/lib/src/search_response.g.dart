// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SearchResponse _$SearchResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SearchResponse', json, ($checkedConvert) {
      final val = _SearchResponse(
        query: $checkedConvert('query', (v) => v as String),
        games: $checkedConvert(
          'games',
          (v) => (v as List<dynamic>)
              .map((e) => GameSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SearchResponseToJson(_SearchResponse instance) =>
    <String, dynamic>{
      'query': instance.query,
      'games': instance.games.map((e) => e.toJson()).toList(),
    };
