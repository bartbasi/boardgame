/// Request and response DTOs shared by the Board Game Collector app and
/// backend. See README.md for the JSON shapes and the compatibility rule.
library;

export 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;

export 'src/error_code.dart';
export 'src/error_envelope.dart';
export 'src/health_response.dart';
