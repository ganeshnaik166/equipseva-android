# English-only cache follow-up — independent QA

Reviewer: `/root/english_cache_qa_1008`, 2026-10-08. Preliminary review only; no acceptance score yet.

## Frozen scope awaiting implementation/evidence

Candidate `work/eqs-english-20261008`, branch `codex/english-guard-inputs-20261008`, observed HEAD `d8f85fcf655a44c98d635121233d0654c54c763f`; parent-owned CURRENT_STATE WIP records the cache-input correction. Read AGENTS, CURRENT_STATE, product plan/delivery acceptance sections, source conventions, English handoff, full English guard, relevant module/CI configuration and main-to-head source diff. No source edits or Gradle processes were started by QA. This report is outside the repository.

Review covers original English-only resource cleanup plus the proposed bounded task-input correction. It does not accept the whole app, device/TalkBack behavior, arbitrary Kotlin build-script interpretation, custom resource source directories, main integration or release.

## Source observations

- The production delta removes `values-hi` and `values-te`, changes the single active Android locale filter to `en`, and edits one historical comment in the default strings file. Default string keys/values and UI source are unchanged. The obsolete parity test is replaced by five stronger source guards.
- `EnglishOnlyResourcesTest.kt:23-52` checks immediate resource directory names, including empty directories. `:150-160` discovers every immediate `src/*/res`, including source-set names which AGP need not configure. `:99-116`, `:121-134` and `:174-181` consume nested XML bytes and file names. `:90-94` consumes raw `app/build.gradle.kts` bytes.
- Therefore compiled Android resources alone cannot key this test correctly. Inactive source sets, XML comments and empty directories are meaningful inputs independent of compiled resources. A single project-relative resource tree prevents collisions between equal relative file names in different source sets; explicit directory paths are needed if the chosen Gradle file input normalizes empty directories away.
- Existing `.github/workflows/android.yml:53-57` restores `~/.gradle/caches`; `:116-117` runs normal tests without forcing rerun. `gradle.properties` enables both task and configuration caches. The handoff's sentence that a clean CI run always executes the guard is unjustified and should be corrected.
- The lexer deliberately is not a Kotlin interpreter: the previously documented dead outer `androidResources` block/custom `res.directories` limitations remain. Current module source has neither issue. Do not broaden the follow-up into a new parser or claim all future Gradle semantics are proven.

## Required before/after controls

1. Warm focused five-test run, then unchanged run showing legitimate UP-TO-DATE or FROM-CACHE behavior.
2. Add an empty locale-qualified directory under a previously absent/inactive source set (for example `src/englishCacheProbe/res/drawable-hi`). Before fix record an incorrect skip; after fix require test execution and the expected directory-guard failure. Remove it and require green.
3. Under reused configuration cache, add a different new source-set root after the previous task graph was cached; prove rediscovery and expected failure. A manifest calculated once and frozen into the cached configuration must not miss it.
4. Mutate raw XML content in an inactive source set so compiled resources remain unchanged (native-script comment, escaped code point or numeric entity). Require execution and the content guard failure, then restore and require green. This separates file-content tracking from directory-manifest tracking.
5. Change only a build-script token which the source guard rejects while runtime locale filtering is unchanged (a suitable source-only decoy/continued-expression probe chosen carefully). Require input invalidation and guard failure. A direct runtime locale-filter mutation can be supplementary, but AGP recompilation alone does not demonstrate the explicit build-script input.
6. Restore exact source and run targeted + full unit/lint/debug checks, plus applicable hosted Android/visual/secret checks. Read actual task outcomes and XML counts. Do not count restored/cached old XML as newly executed verification.
7. After unchanged success prove caching remains usable, rather than blanket disabling caching/up-to-date checks. Check configuration-cache diagnostics for captured Project/build-script objects or unsupported task inputs.

Useful secondary controls: rename one empty locale directory to another while preserving directory count; create ordinary unqualified empty resource directory and demonstrate a harmless re-execution/pass; source path normalization must remain relocatable across isolated checkouts and Windows/Linux. No extra dependency or permanent failure fixture is necessary.

## Pending final disposition

Await parent-owned minimal diff, exact frozen SHA, before/after logs and full verification. No QA score or new acceptance is claimed. Prior 9.6 provenance cannot substitute for this review.

## Frozen-source and probe review — 60579c47

Re-reviewed at exact source `60579c4738efc04d7204b023670bf65021450495`. Follow-up production/build delta is only 15 lines in `app/build.gradle.kts`: a live `fileTree("src")` including `*/res/**`, declared as a relative task input with empty directories retained, plus the raw module build script as a relative file input. The guard assertions remain unchanged. All three fingerprinted files match this Git source after the checkout's standard CRLF-to-LF normalization; raw working-file SHA-256 values match the archived probe receipts. Git status was clean.

Independent Python XML comparison of main `49c163eb` versus this head found all default resource nodes/attributes/text unchanged (766 named string resources). The changed default-file text is comments only. Original locale deletions and obsolete parity-test removal match the approved scope.

Read the probe harness, receipt JSON, raw logs and archived JUnit assertions. These were parent-executed checks, independently reviewed by QA:

| Control | Observed result |
|---|---|
| Before fix, empty new inactive source-set `raw-te` | Normal run incorrectly UP-TO-DATE with retained 5/0; forced rerun executes 5/1, correct directory failure |
| After fix, same new root | Actual execution 5/1, correct directory failure; configuration cache reused; compiled resource/Kotlin tasks UP-TO-DATE |
| After fix, empty `debug/res/drawable-b+te+IN` | Actual execution 5/1, correct directory failure; configuration cache reused |
| Ordinary empty new root `res/raw` | Actual execution 5/0, showing benign additions are not falsely rejected |
| Native-script XML comment | Actual execution 5/1, correct content guard; `processDebugResources` and Kotlin compilation UP-TO-DATE |
| Duplicate `en` in build-script `setOf` | Actual execution 5/1, only build-script guard fails; actual Set value remains English and compiled resource/Kotlin tasks stay UP-TO-DATE |
| Clear test output and restore | Supported clean-test task removes test output; next focused run restores 5/0 FROM-CACHE |
| Another fresh empty `res/values-hi` after restore | Actual execution 5/1 with configuration cache reused; dynamic file tree rediscovers the new root |
| Restore original files and unchanged runs | 5/0 FROM-CACHE restoration; unchanged no-op UP-TO-DATE, preserving useful caching |

The duplicate-en build-script probe is an adequate replacement for the suggested unused-identifier probe: it changes source while preserving actual set semantics and does not recompile resources. Likewise the XML comment leaves processed resources and test classes unchanged. No additional mandatory probe is identified for this bounded input correction. Restored XML counts are intentionally labeled cache restoration, not new execution.

Full unit/lint/debug is still running as of this review; final score withheld until its completed evidence is inspected. Hosted and release gates remain separate. Public continuity documents must supersede the false clean-CI-execution assertion and historical unresolved review provenance before integration.

## Final local implementation QA — 8 October 2026

**QA: 9.6/10 for the whole local English-only resource cleanup plus cache-input correction at `60579c4738efc04d7204b023670bf65021450495`. No unresolved local source/test blocker.** Exact app tree independently read from Git: **`91629ae6ceb6d7b95b1742073fc6f4b0c4873c1f`**. This is a new review of the present source and evidence; it does not inherit the historical unresolved `00a30ef5` score.

### Completed evidence inspected

- Parent-executed full command in `full-unit-lint-debug.json` and raw log exited 0 in 6m31s. `:app:testDebugUnitTest` executed, rather than returning UP-TO-DATE/FROM-CACHE. Independently parsed all 350 archived JUnit files: **2,989 tests / 0 failures / 0 errors / 0 skips**. English guard is 5/0; its archived suite timestamp is 2026-10-08T07:53:30.113Z. The recorded source fingerprints match the frozen candidate's Windows working files.
- Independently parsed lint XML: **0 errors / 87 warnings / 2 hints**. Debug assembly succeeded in the same command. Existing warnings are not relabeled as zero or suppressed.
- Design ratchet's UTF-8 rerun log is green with no changed baseline/rule/source. The earlier cp1252 printing exception remains a failed tooling invocation; this QA does not reinterpret it as a successful first run.
- No source diff under `app` after the frozen commit. All named synthetic probe roots and the debug locale probe directory are absent. Working changes observed for the final handoff are documentation only.
- The corrected historical handoff now explicitly says clean checkout does not prevent cache reuse and points at the fresh proof. New detailed handoff distinguishes negative controls, valid cached restorations, full execution and future hosted/release gates.

### Scope-aware rubric

| Dimension | Local score | Basis / boundary |
|---|---:|---|
| Correctness, 25% | 9.7 | Current conventional resource tree and module script are keyed; independent positive and negative controls prove execution, discovery and valid reuse. Arbitrary custom resource roots/Kotlin semantics remain outside the guard contract. |
| Security/privacy, 25% | 9.6 | Strict existing XML parser retained, invalid qualified directories fail closed, no network/account/credential change or weakened gate. This is source-guard safety, not an app security audit. |
| Recovery/data, 20% | 9.6 | Repeated remove/restore/cache-clear/new-root transitions succeed; no runtime data migration or destructive recovery change. Runtime account/data recovery is out of scope. |
| Usability/accessibility, 15% | 9.5 | Requested English-only catalogue behavior and all default labels preserved; full regression suite green. Device/TalkBack/large-font checks remain release gates, not claimed here. |
| Visual consistency, 10% | 9.5 | No screen/token/default-label/golden alteration; no local screenshot score claimed. New hosted golden verification remains required. |
| Performance/operations, 5% | 9.7 | Live filtered input tree preserves configuration cache and valid task cache reuse instead of blanket disabling caches; no dependencies added. |

Weighted local total 9.605, reported as **9.6**. Deductions reflect deliberately bounded scanner semantics, platform/hosted checks still outstanding, and lack of an automatic persistent mutation harness in the repository; the recorded probes are reproducible but manual. None is a new local implementation blocker for this small build-input change.

### Publication corrections and remaining gates

Two factual handoff corrections were requested and then independently re-read as applied: the app-tree hash now matches `...95b174...` (actual Git above), and the XML-comment probe says **`processDebugResources` stayed UP-TO-DATE** while **`mergeDebugResources` executed**. No app-source changes accompanied these corrections. The identified local receipt issues are closed.

Local source acceptance does **not** accept the new hosted Android/R8/golden/secret checks, combined target/main integration, device/TalkBack behavior, signed assembly or production/release. Those remain explicit future gates. No Claude-owned branch, public main or website was edited by this reviewer. QA ran only source/evidence inspection scripts, never Gradle, and independently audited the parent's recorded execution.
