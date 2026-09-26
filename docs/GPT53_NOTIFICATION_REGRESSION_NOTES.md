# Notification mapper regression notes — 11 September 2026

Scope: tests only in the new `NotificationDeepLinkEdgeCasesTest.kt`, plus this
report. Production mapper and all pre-existing test files are unchanged from
`1e770076358e74f6f40a99a4907f831da59e791c`.

## Contract actually inspected

`app/src/main/kotlin/com/equipseva/app/navigation/NotificationDeepLink.kt` is a
pure `(kind, Map<String, String>) -> String?` mapper. It does not receive a
session, role or row-owner identity. UUID fields are checked by the hexadecimal
8-4-4-4-12 pattern at lines 34–35, not by version/variant or server ownership.
Repair job identifiers also accept case-insensitive `RPR-` plus 1–8 ASCII digits
(`:42,162–163`). UUID-only chat, engineer and contract fields do not accept job
codes. Matching is exact: strings are neither trimmed nor percent-decoded.
Missing/unknown kind or required ID returns null; caller inbox fallback is not
part of this unit test. Several known destinations deliberately need no ID.

The original 14 helper tests were retained and extended to 22. Two names that
claimed inbox behavior now accurately say “returns null”; all 14 had passed
before that wording change. No failed test was removed, ignored or relabeled.
New cases cover all 19 job-lifecycle kinds, seven nonprivileged no-ID mappings,
all three contract kinds, wrong/missing keys, key precedence, uppercase UUIDs,
RPR lower/upper limits, whitespace/control characters, slash/backslash/query/
fragment strings, encoded/double-encoded values, non-ASCII digits, altered and
retired kinds, and bounded 4096-character adversarial strings.

## Current behavior versus security targets

These passing tests characterize route mapping for legitimate inputs and its
existing malformed-input rejection. They do **not** authorize navigation or
prove API access control. No parser defect was reproduced by these cases.
There is no new failing security-target test in this milestone and no WIP test
was hidden. A3 must add explicit role/session/ownership tests at the actual
admission boundary once the coordinator freezes its policy.

Static follow-up, already tracked by Claude as A3-01/A3-02:

- Mapper `:100–102` returns founder queue routes for the three admin kinds,
  without role information. Reproduction recipe: call `routeFor` with
  `KIND_ADMIN_ENGINEER_AUTO_SUSPENDED` and an empty map, then trace the returned
  candidate through the admission boundary. No new assertion freezes this
  privileged route as acceptable. The mapping alone does not prove server data
  exposure; authorization belongs at the validated route/sink and server.
- `DeepLinkRouter.kt:40–43` prefers the verbatim `EXTRA_ROUTE` string over URI
  resolution; `MainActivity.kt:63,103–106` dispatches initial/new intents. This
  bypasses pure-mapper validation entirely. A malformed-ID mapper pass cannot
  close the exported-intent issue.
- `DeepLinkRouter.kt:35–36` retains a buffered channel. `DeepLinkHost.kt:170–177`
  still buffers and forwards OpenRoute as-is after A10. Engineer-status login
  ownership does not own those event buffers. Cross-account event replay is
  still A3 work, including notification-tray handling.

These are source-level reproduction paths, not a newly executed device attack.
Claude's fetched docs-only review is at
`origin/claudedev-next-review-20260911`, head
`0d4269ea70d2fd2f87addcc9c0c4e6325b19c4aa`; see its
`docs/HANDOFF_CLAUDE_NEXT_REVIEW.md`. A10 should integrate before A3 modifies
DeepLinkHost. Do not treat this test result as A3 acceptance.

## Executed evidence

```text
.\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.NotificationDeepLinkEdgeCasesTest --max-workers=2 --no-configuration-cache
BUILD SUCCESSFUL in 10s
JUnit XML: 22 tests, 0 failures, 0 errors, 0 skipped
```

Synthetic strings only; no account, FCM delivery, network request or Android
device in these tests. Log and XML are preserved locally under
`C:/Users/lokes/Documents/Codex/2026-09-07/im/work/verification/gpt53-helper-20260911/`
as `notification-edge-cases.log` and `notification-edge-cases.xml`.
Coordinator integration and independent critic/QA acceptance remain separate.
