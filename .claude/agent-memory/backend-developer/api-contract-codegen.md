---
name: api-contract-codegen
description: How packages/api_contract uses freezed 4 and json_serializable (checked mode, committed generated files, coverage, unknown enum handling)
metadata:
  type: project
---

api_contract DTOs use freezed 4.x (MIT) + json_serializable 6.x (BSD-3) with `build.yaml` options `checked: true` and `explicit_to_json: true`. Generated `*.freezed.dart` / `*.g.dart` are committed (proposed in T-007 handoff, 2026-10-12).

**Why:** app/ and server/ consume the package by path (T-004 decision); the server Docker image uses plain `dart:stable` and should not need build_runner. Generation was verified byte-identical between Windows and linux/amd64 Docker (Dart 3.13.5).

**How to apply:**
- After editing a DTO: `dart run build_runner build` in packages/api_contract and commit the output (`--delete-conflicting-outputs` is removed in build_runner 2.16; it warns and ignores it).
- Decoding failures (missing, null, wrong type) surface as `CheckedFromJsonException` with `.key` naming the field; api_contract re-exports it.
- Forward-compatible enums: `@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)` plus `@JsonKey(unknownEnumValue: X.unknown)` on the field. `alwaysCreate` gives `_$XEnumMap` for a `wireName` getter.
- freezed 4 syntax: `@freezed abstract class X with _$X { const factory X({...}) = _X; factory X.fromJson(...) }`; no `final` in constructor params (Dart 3.13).
- freezed files carry `// coverage:ignore-file`, so coverage counts only hand-written and `.g.dart` lines.
- Coverage: `dart run coverage:test_with_coverage` (coverage dev dep) writes coverage/lcov.info.
- Use the SDK binary `C:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe` to prove "no Flutter"; Docker `dart:stable` needs the repo layout (root analysis_options.yaml two levels up) or analyze warns include_file_not_found.

Related: [[worktree-shell-limits]]
