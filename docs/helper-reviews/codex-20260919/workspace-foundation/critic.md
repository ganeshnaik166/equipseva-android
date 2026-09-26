# Independent code critic — registration intent and region draft

Date: 19 September 2026. Reviewer: independent `product_plan_critic` agent.

**Disposition: accepted for the exact four-file preparatory code scope. Independent critic score: 9.5/10. No actionable blocker found.** The completed targeted GREEN and lint evidence below was independently inspected. This is not app-wide, P1, integration, security-certification or release acceptance.

## Exact scope

Base: `ccda4e4addef7e995f6e55a106c703dbee7af253`, `work/equipseva-quality-integration-20260919`. The reviewed working tree adds exactly four files; existing tracked files are unchanged:

| File | SHA-256 |
|---|---|
| `app/src/main/kotlin/com/equipseva/app/features/auth/PublicRegistrationIntent.kt` | `C4720657E509943D99B7AAD65202D3D6649917D3FA90BBE2AC12A5369392B497` |
| `app/src/main/kotlin/com/equipseva/app/core/data/location/RegionSelectionDraft.kt` | `8469E31314BC3BD1C9BAC30D093D34B5562AA120826C72127C1FC9B8A1B0D084` |
| `app/src/test/kotlin/com/equipseva/app/features/auth/PublicRegistrationIntentTest.kt` | `D5247ED3021741EC749AFC47ACDA7462AB6639C3DCD1FAB1D792A2DA2CC69E7B` |
| `app/src/test/kotlin/com/equipseva/app/core/data/location/RegionSelectionDraftTest.kt` | `7AC77CC76BC347B3943E791D320CBBE3B908ADB5F05C9F04F10D21783A1D0F84` |

The types are unused preparation. The production-name search returns only their own declarations/methods. There are no changes to `UserRole`, authentication, routing, `SessionPresentation`, SQL, permissions, billing, catalog contents or a UI consumer. The critic did not run Gradle, modify app files, alter the product-plan review, or push anything.

## Source findings

No actionable correctness or security-boundary defect found in the declared scope.

- `PublicRegistrationIntent` is internal and carries exactly three stable local-draft keys. Exact equality rejects null, unknown, privileged, legacy backend-role, case-altered, whitespace, encoded and embedded variants without a fallback. It neither maps to `UserRole` nor creates an authority claim. Comments identify the local-only contract.
- `RegionSelectionDraft` has a private constructor and immutable String properties. Every public construction/transition path preserves either empty, a valid known state without a district, or a district selected from that exact state's bundled list. Consequently `isComplete` is valid for the limited local-selection invariant.
- State validation uses exact membership in `IndiaLocations.STATES`. District validation uses `IndiaLocations.districtsFor`, whose implementation is an exact map lookup. The new code never invokes the legacy `canonicalState` substring-normalization helper.
- Selecting a new state clears the district even when the same district name exists in both states. Selecting the same exact state preserves its valid district. Invalid state input clears both fields; invalid district input clears only the district. A district cannot manufacture a missing parent state.
- `restore` traverses the same validated transitions. It cannot restore an incompatible pair or adopt a recognized district under an unknown parent. New selections do not mutate earlier draft instances. No side effects, concurrency, serialization or persistence mechanism is introduced.

## Test relevance and evidence

The 24 new tests cover actual boundaries: the three valid saved choices; rejected privilege/backend keys and malformed variants; empty/parent-only/complete drafts; missing parent; wrong district; cross-state same-name transition; same-state preservation; invalid selections; restored input; immutable earlier snapshots; and compatibility with every currently bundled state/district pair. Existing `IndiaLocationsTest` and `UserRoleEnumTest` are appropriate adjacent regression coverage.

Independently read archived `red-xml` and compiling `red-source` plus `intent-region-red.log`:

| RED suite | Tests | Failures | Errors | Skipped |
|---|---:|---:|---:|---:|
| `PublicRegistrationIntentTest` | 8 | 3 | 0 | 0 |
| `RegionSelectionDraftTest` | 16 | 11 | 0 | 0 |
| Total | 24 | 14 | 0 | 0 |

Both current test hashes exactly equal the archived RED test files. The failures are assertions against deliberately compiling new-feature stubs, not compilation errors or a reproduced old production vulnerability. Negative cases that already passed against null/empty stubs remain meaningful rejection guards; the positive failures demonstrate that the stubs did not implement the promised behavior.

**GREEN/lint receipt:** independently parsed `green-xml` after coordinator completion: `PublicRegistrationIntentTest` 8, `RegionSelectionDraftTest` 16, `IndiaLocationsTest` 13 and `UserRoleEnumTest` 8; **45 tests, zero failures, zero errors, zero skips**. `intent-region-green.log` records `BUILD SUCCESSFUL in 5m 1s` with `lintDebug` completed. Archived `lint-green.xml` contains **zero errors, 89 warnings and two hints**. All four current source hashes still equal the reviewed hashes above, and both tests remain byte-identical to RED. Execution was performed by the coordinator, not the critic.

The 9.5 judgment reflects complete handling of the narrow input/transition invariants, deliberately absent authority/UI integration and credible unchanged-test RED/GREEN evidence. It does not claim more than this boundary. Broader full-unit/debug/unsigned-R8 verification is separate and was not available for this receipt; existing app-wide failures cannot be averaged into a passing app score.

## Scope limits and future consumer obligations

1. Completeness means a pair exists in the **legacy bundled catalog**, not that its geography is current, official, server-validated or proof of identity/attendance. The existing catalog's dated/conflicting comments are not repaired here. Canonical LGD codes/version migration remains separate work.
2. Invalid restored values intentionally become unresolved selection. A future migration/UI must preserve raw legacy text separately for display/correction where the product plan requires it; this type is not a legacy-record migration or persistence adapter.
3. Three enum values do not deliver three-role signup, a demo, a team workspace, subscription or founder protection. Actual membership/resource/entitlement decisions remain server work. This code has no current UI render/device acceptance claim.
4. P1 cleanup and session recovery are untouched. The existing three cleanup failures, S3 recovery, payment/integrity findings and 116 changed screenshot cases remain outside this slice and unresolved by it. This focused green run is not a new full-suite green or app-release acceptance.

No additional tests or app changes are requested by this source review. Re-review these types when a consumer adds persistence, catalog versions or authority-adjacent flow behavior.
