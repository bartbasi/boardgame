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
- Value rules (T-018): use `JsonConverter<T, Object>` (non-null JSON type). With `Object?` json_serializable calls the converter with null even for nullable fields, so optional fields reject null; with `Object` it wraps nullable fields in `_$JsonConverterFromJson` and casts required ones. Plain `int` fields decode via `(v as num).toInt()`, which silently truncates 1.5; the converters in lib/src/converters.dart reject that.
- Cross-field checks: `factory X.fromJson(json) => _check(json, _$XFromJson(json));` works with freezed; throw `CheckedFromJsonException(json, key, className, message)` yourself.
- Adding an ErrorCode value breaks the app compile: app/lib/core/data/network/failure_mapper.dart had an exhaustive switch with no wildcard (intentional per decisions.md 2026-10-13: whoever adds a value updates the app in the same change). Check app/ for exhaustive enum switches before adding enum values; app.yml runs on packages/api_contract changes.
- Wildcards (`_`) in Dart switch over enums are fine for coverage; Python heredocs with `'''` inside Bash fail in this harness, use Edit or a script in a git-ignored .dart_tool/ folder.
- Use the SDK binary `C:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe` to prove "no Flutter"; Docker `dart:stable` needs the repo layout (root analysis_options.yaml two levels up) or analyze warns include_file_not_found.

Related: [[worktree-shell-limits]]
- DateTime.parse rolls impossible dates over (month 13, hour 24, second 60) and double.toInt() clamps beyond int range; validate both (T-018 B1, B2).
- Before coding, re-read the ticket as it is on main (merge main first): T-018 AC2 changed on main before the branch and the round 1 code followed the stale wording.
