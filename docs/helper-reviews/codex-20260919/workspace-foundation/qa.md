# Independent QA — unused registration-intent and region-draft preparation

Reviewed 19 September 2026. **QA result: 9.6/10 for the four-file source and targeted-test scope. No blocking finding in that scope.** This is not an app-wide, integration, live-role, migration, UI or release rating. Draft PR 1877 and its existing S1/S3, payment, screenshot and release blockers remain unaccepted.

## Exact reviewed boundary

Base: `ccda4e4addef7e995f6e55a106c703dbee7af253` in `work/equipseva-quality-integration-20260919`. At inspection, the only application changes were the following four untracked new files; the tracked source diff was empty. Paths below are relative to that repository.

| File | SHA-256 |
|---|---|
| `app/src/main/kotlin/com/equipseva/app/features/auth/PublicRegistrationIntent.kt` | `C4720657E509943D99B7AAD65202D3D6649917D3FA90BBE2AC12A5369392B497` |
| `app/src/main/kotlin/com/equipseva/app/core/data/location/RegionSelectionDraft.kt` | `8469E31314BC3BD1C9BAC30D093D34B5562AA120826C72127C1FC9B8A1B0D084` |
| `app/src/test/kotlin/com/equipseva/app/features/auth/PublicRegistrationIntentTest.kt` | `D5247ED3021741EC749AFC47ACDA7462AB6639C3DCD1FAB1D792A2DA2CC69E7B` |
| `app/src/test/kotlin/com/equipseva/app/core/data/location/RegionSelectionDraftTest.kt` | `7AC77CC76BC347B3943E791D320CBBE3B908ADB5F05C9F04F10D21783A1D0F84` |

The coordinator supplied the execution receipt; QA independently read the archived XML/logs and source, compared the tests byte-for-byte with the RED archive using SHA-256, and confirmed identical RED/GREEN test-name sets. QA ran no Gradle, provider calls, builds or pushes and edited no repository source or tests.

## Execution evidence independently checked

All evidence paths here are relative to this output directory.

| Evidence | Observed result |
|---|---|
| `red-xml/` and `red-source/` | **24 tests, 14 failures, 0 errors, 0 skipped**: intent 8/3 failures; region 16/11 failures. All failure types are `java.lang.AssertionError`. RED production files are explicitly labelled compiling stubs. This demonstrates test-first implementation of new behavior, not regression reproduction against an older shipped feature. |
| RED/GREEN test equality | Both current test-file hashes exactly match `red-source/`; test-name differences are zero for both classes. No assertions were weakened to obtain GREEN. |
| `green-xml/` | **45 tests, 0 failures, 0 errors, 0 skipped**: 24 new tests plus `IndiaLocationsTest` 13 and `UserRoleEnumTest` 8. |
| `intent-region-green.log` | `BUILD SUCCESSFUL in 5m 1s`; the targeted unit task and `lintDebug` completed. Coordinator reported process exit 0. |
| `lint-green.xml` | **0 errors, 89 warnings, 2 hints**. This is a successful lint gate with existing warnings, not a warning-free application. |

## Source and assertion review

**Registration intent:** exactly three internal enum values have stable local-draft keys. Parsing uses exact equality and returns null for missing, malformed, future, backend-role and privileged values. Tests independently pin the three keys and their distinctness, every permitted round trip, privilege/backend-role rejection, casing/whitespace, encoded/embedded/NUL/zero-width variants and unknown values. No default selection, role conversion, persistence, repository call or permission grant is introduced.

**Region draft:** the constructor is private, state is immutable, and every normal factory/transition validates exact membership in the existing bundled names. District selection requires its parent. Changing state clears the district even when the same label exists under both parents; reselecting the same exact state preserves the selected district. Invalid states clear both selections; an invalid district preserves only a valid parent. Restoration goes through the same validation, and completeness cannot be obtained through a public unchecked constructor or generated copy method.

The assertions cover blank/unknown inputs, wrong-parent district, no parent, case/whitespace/substring rejection, invalid replacement after a valid selection, valid and malformed restoration, same-state preservation, same-named district under a different state, previous-instance immutability and positive compatibility for all listed bundled pairs. The Bilaspur case first asserts that both catalog parents contain that name, so the fixture cannot silently stop exercising the intended ambiguity. Positive ordinary controls accompany rejection cases. The all-pairs loop characterizes the bundled catalog; the representative cross-parent and state-change assertions supply the independent negative checks.

**Production isolation:** an `rg` scan of `app/src` found references only in these two definitions and their two tests. Both types are `internal`; neither is used by auth, `UserRole`, session/root navigation, workspace admission, profile writes, SQL, billing or existing location UI. Existing `IndiaLocations.districtsFor` performs direct map lookup, and the new draft does not use its fuzzy `canonicalState` helper. Existing authorization keys and catalog source remain unchanged and their 21 companion tests pass.

## Scope limits and next-use conditions

- These are unused preparation types. They do not implement P1 safety, an organisation signup page, invitations, a demo, workspace membership or a paid feature.
- `isComplete` means only that the local draft contains a pair from the legacy bundled names. It is not current LGD validity, server authority, verified identity/address, service eligibility or attendance. Official IDs/versioned catalog migration remain P2 work.
- The factory intentionally returns an incomplete selection for invalid legacy input. A future UI/migration consumer must separately preserve/display unresolved original values and provide correction; this unused type is not a migration or persistence policy.
- No UI, accessibility, locale, device, process-death persistence, SQL/RLS, provider, full-unit, APK, signed-release or screenshot result is inferred from this targeted receipt. Those unrelated checks were not performed by QA and do not become accepted through this score.
- The three existing cleanup failures must remain enabled. S1/S3 repair and all broader PR 1877 gates remain separate even if a later full run reproduces only the known failures.

The 9.6 score reflects clear API invariants, effective positive/negative contract assertions, verified RED-to-GREEN evidence, and confirmed absence of runtime integration. It applies only to the hashes and boundary above; connecting these types to live behavior requires a new review and the relevant server, recovery and UI evidence.
