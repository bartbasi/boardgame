/// Request and response DTOs shared by the Board Game Collector app and
/// backend. See README.md for the JSON shapes and the compatibility rule.
library;

export 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;

export 'src/error_code.dart';
export 'src/error_envelope.dart';
export 'src/game_detail_response.dart';
export 'src/game_summary.dart';
export 'src/health_response.dart';
export 'src/lookup_response.dart';
export 'src/search_response.dart';
