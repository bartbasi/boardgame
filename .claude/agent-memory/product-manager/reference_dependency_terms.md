---
name: reference-dependency-terms
description: Where the official license and terms pages live for app dependencies that touch the license rule or privacy forms (mobile_scanner, Google ML Kit)
metadata:
  type: reference
---

- mobile_scanner: https://pub.dev/packages/mobile_scanner. BSD-3-Clause. On Android it bundles Google ML Kit by default (an unbundled variant goes through Play services via a gradle property). On iOS it uses Apple Vision. Checked 2026-10-11.
- Google ML Kit terms: https://developers.google.com/ml-kit/terms. They fall under the Google APIs Terms of Service, not an OSS license. ML Kit sends usage metrics to Google, and the developer must disclose that to users. Checked 2026-10-11.

Why it matters: the brief mandates mobile_scanner, but the project rule allows only MIT, BSD, or Apache 2.0 without user approval. ML Kit is PRD open question Q4, and it feeds the privacy policy and Data Safety answers.

How to apply: re-check both pages if more than 90 days old before T-030, T-078, or T-079 relies on them. When a plugin pulls in a native SDK, check the SDK's own terms, not only the Dart package license. See [[criteria-patterns]].
