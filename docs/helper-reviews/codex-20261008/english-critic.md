# Independent critic — English-only resources and raw-source cache repair

Review date: 8 October 2026. Frozen source commit: `60579c4738efc04d7204b023670bf65021450495`. App tree: `91629ae6ceb6d7b95b1742073fc6f4b0c4873c1f`. Base: `49c163ebfe9bacc6b693b95a5218c9c1ac749dd8`. Owned worktree: `work/eqs-english-20261008`.

**Final independent critic: 9.6/10 for the complete English-only resource implementation and raw-source cache repair, locally verified at the frozen source above. No unresolved mandatory code defect in this bounded local scope.** This review does not accept the new candidate's hosted checks, main integration, device/TalkBack or signed release. The reviewer inspected source and saved coordinator-run evidence; the reviewer did not run Gradle or alter implementation. A handoff app-tree transcription error was reported, corrected by the coordinator, and rechecked; the exact reviewed tree is the Git-derived `91629ae6ceb6d7b95b1742073fc6f4b0c4873c1f` recorded here.

## Reviewed scope and correctness

The complete main..60579c47 diff changes 11 files (+423/-1997): the English-only locale filter, removal of the Hindi/Telugu catalogues and old translation-parity test, five replacement policy guards, a comment-only update to the default catalogue, raw-input cache declarations, and continuity documents. No screens, default string keys/values, other tests, screenshots, SQL, Edge or web implementation changed. `git diff --check` passes, and the owned app working tree matches the frozen commit.

The follow-up after Claude's `d8f85fcf` adds exactly 15 build-script lines, plus a six-line ownership/scope record. `app/build.gradle.kts:52-55` defines a live filtered tree rooted at `src`. Lines 200-208 declare that tree and the module build script as test inputs with relative path sensitivity and explicit directory sensitivity. They neither change guard assertions nor force unconditional execution. The callback applies to Android unit-test tasks, preserving ordinary task cache reuse.

This matches what `EnglishOnlyResourcesTest` observes: conventional `src/*/res` roots, empty qualified directories, raw XML, font names, and raw Gradle syntax. There is no eager snapshot of today's source roots and no flattening that would discard directory topology. The ordinary English resource behavior, secure XML parser settings and constrained locale-filter policy remain unchanged from the reviewed original scope.

## Independently inspected evidence

Receipts, raw logs and archived JUnit were read under `outputs/claude-intake-20261008/english-verification`. The three frozen raw-file SHA-256 values match the after-repair receipts:

| File | SHA-256 |
|---|---|
| `app/build.gradle.kts` | `7ab3a87e782e4c1b2e37bd45e28ab3317ea00b530f23f4a3984cd256d1b34f43` |
| `app/src/main/res/values/strings.xml` | `2571948c76a3cd6bebc64891b4911016fb4c3147d2e8c1d1e252d1726ac6b5d4` |
| `EnglishOnlyResourcesTest.kt` | `0fa5991128a79f4c1256dd3f914fe0b406cfce2d249600248e55fdd2974fda00` |

| Receipt label | Actual task result | Archived guard result and interpretation |
|---|---|---|
| `before-empty-stale` | `UP-TO-DATE`, exit 0, configuration cache reused | Retained 5/0; this is stale success, not fresh execution |
| `before-empty-forced-red` | Executed/failed, exit 1 with explicit `--rerun` | 5/1, only locale-directory guard; names `src/englishCacheProbe/res/raw-te`, establishing the earlier skipped condition really violates policy |
| `after-baseline` | Executed, exit 0 | 5/0 |
| `after-new-root-red` | Executed/failed, exit 1, configuration cache reused | 5/1, only directory guard; same `src/englishCacheProbe/res/raw-te` |
| `after-existing-root-red` | Executed/failed, exit 1 | 5/1, only directory guard; `src/debug/res/drawable-b+te+IN` |
| `after-xml-comment-red` | Executed/failed, exit 1 | 5/1, only native-script guard; default `values/strings.xml` |
| `after-build-script-red` | Executed/failed, exit 1 | 5/1, only build-script guard; duplicate-English expression is rejected despite equivalent runtime Set |
| `after-noop` | `UP-TO-DATE`, exit 0 | Retains valid 5/0; caching was not disabled |
| `after-valid-new-root` | Executed, exit 0 | 5/0 with valid ordinary empty resource directory |
| `after-valid-root-removed` | `FROM-CACHE`, exit 0 | Valid baseline 5/0 restored after source-root deletion |
| `after-cache-restore` | `FROM-CACHE`, exit 0, configuration cache reused | Valid baseline 5/0 restored after clearing only test outputs |
| `after-cache-fresh-root-red` | Executed/failed, exit 1, configuration cache reused | 5/1, only directory guard; fresh `src/englishCacheProbeFresh/res/values-hi` prevented stale cache reuse |
| `after-final-green` | `FROM-CACHE`, exit 0, configuration cache reused | Valid baseline 5/0 restored after removing the final probe |

All after-repair negative XML suites report 5 tests, 1 failure, 0 errors and 0 skipped; each failure method and message matches the intended mutation. Restored source states return 5/0. The distinction between executed tests, retained reports, UP-TO-DATE and FROM-CACHE is preserved. A forced rerun appears only in the before-fix diagnostic receipt, not in after-fix invalidation evidence.

The original cache concern is now reproduced and repaired for the declared conventional resource scope. It was a regression-guard enforcement defect under inherited Gradle caching; no production resource leakage was demonstrated by these synthetic probes.

## Remaining boundaries and required documentation

- Full unit/lint/debug evidence has now been independently checked, as recorded below. Hosted verification of the new candidate remains pending and is not replaced by local success.
- The independent final review will pin `60579c47` and its app tree directly. Historical `00a30ef5` QA provenance remains unavailable, but is not needed to infer the new review's scope: this reviewer examined the complete main..60579c47 source, not merely the cache follow-up.
- Correct public continuity records before publication: remove the unconditional claim that a fresh CI checkout always executes the guard, retain the original stale success and diagnostic failure, and record new exact-source evidence without retroactively relabeling earlier reviews.
- Custom resource directories outside `src/*/res`, arbitrary Kotlin control-flow proof, hidden/version-control metadata directories, semantic language classification and dependency-resource runtime inspection are outside the guard contract. Current source has no custom resource root or enclosing dead locale-filter block; these are bounded limitations, not current production defects found here.
- Hindi-system-locale number/date tests, existing nontranslatable markers and the unchanged fallback test remain valid; no cleanup of them is required by this cache fix.
- Hosted exact-head Android/goldens/Gitleaks checks, main integration, device/TalkBack, store languages and signed release remain separate gates.

## Final full-bar receipt and score

The completed `full-unit-lint-debug.json` binds the same three source-file hashes listed above and records exit 0 for `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug`, from 07:51:44 to 07:58:16 UTC. The raw log shows actual execution of the full test task, lint and debug assembly, and `BUILD SUCCESSFUL in 6m 31s`. Independently summing all 350 archived JUnit XML suites yields **2,989 tests / 0 failures / 0 errors / 0 skipped**. This is fresh full-task execution, not merely a retained focused report.

The generated `app/build/reports/lint-results-debug.xml` contains **0 errors / 87 warnings / 2 hints**. A debug APK exists at the expected path; neither its existence nor this review is signed-release acceptance. The source remains byte-matched to frozen `60579c47` after the probe/full run. The UTF-8 design-ratchet log reports `RATCHET OK`; neither the verifier source nor baseline changed in this diff. The coordinator separately reported an initial cp1252 `UnicodeEncodeError` while printing a checkmark, retained as a failed tooling invocation in the handoff rather than silently counted as a pass.

**Score: 9.6/10, bounded local source and test-evidence acceptance.** The rating is based on the reproduced pre-fix stale success, five discriminating post-fix negative cases with exact failing methods, correct ordinary topology/deletion behavior, retained configuration/build-cache reuse, source-hash continuity and the fresh full bar. It is not inherited from historical review numbers.

The governing rubric is applied only to this source slice: correctness 9.7 (25%), security/privacy preservation 9.6 (25%), cache-state recovery and unchanged data/money paths 9.6 (20%), source-level English/fallback usability preservation 9.5 (15%), unchanged default visual resources 9.5 (10%), and build performance/operations 9.7 (5%). Weighted result 9.61, reported as 9.6. These dimension ratings assess the changed/local source boundary; they are not fresh whole-app security, financial, visual or accessibility certifications. Device behavior and hosted screenshot comparison remain excluded.

Residual deductions reflect the deliberately constrained source conventions and build-script lexer, the additional resource-input snapshot cost (no performance benchmark claimed), and the lack of runtime packaged-resource inspection in this local review. None is an unresolved mandatory defect in the declared conventional-resource scope. Future custom source roots or arbitrary Kotlin configuration changes require updating both scanner and inputs.

The proposed owned branch may proceed to a review PR directly against main while retaining Claude's English ancestry. The publication tree hash is corrected and rechecked. Record fresh critic/QA reports, then require the new candidate's own exact-head hosted Android/goldens/Gitleaks gates. This score grants no automatic permission to merge, supersede another PR, ship, or widen the assessed scope.
