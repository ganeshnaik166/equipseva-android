# English resource guard cache follow-up — 8 October 2026

## Scope and source

Owned branch `codex/english-guard-inputs-20261008`, isolated checkout `work/eqs-english-20261008`, base `d8f85fcf655a44c98d635121233d0654c54c763f` (English PR1912). Frozen code **`60579c4738efc04d7204b023670bf65021450495`**, app tree **`91629ae6ceb6d7b95b1742073fc6f4b0c4873c1f`**. Follow-up owns only unit-test input declaration and safe continuity records. Claude's region/reliability branches and website hold are preserved.

The existing English guard scans raw conventional `app/src/*/res` trees, including empty directories in source sets AGP does not compile, and reads `app/build.gradle.kts`. Previously these observations were missing from Gradle's test cache inputs. An invalid source change could therefore return an earlier success without running the guard.

The fix adds a live filtered FileTree, named inputs with relative path sensitivity, explicit empty-directory sensitivity, and the raw module build script to Android unit-test tasks. It keeps caching enabled and changes no test assertion, resource value, screen, runtime behavior, golden, dependency or CI gate. The inherited English-only change still removes the two translation catalogues and packages English; 766 default string values/attributes remain unchanged against main after ignoring XML comments.

## Executed cache evidence

Each focused command used `gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.i18n.EnglishOnlyResourcesTest --console=plain`, with the repository's build cache and configuration cache enabled. All probes were synthetic and removed afterwards. No production accounts or networked app flows were exercised.

| Control | Observed result |
|---|---|
| Original warm baseline | 5 tests, 0 failures; task executed |
| Original unchanged run | UP-TO-DATE; configuration cache reused |
| Original new empty `src/englishCacheProbe/res/raw-te` | Incorrect UP-TO-DATE success: guard did not execute |
| Same original violation with task-level `--rerun` | 5 tests / 1 expected directory-guard failure, proving fixture validity |
| Original source restored | Valid 5/0 result restored FROM-CACHE |
| Fixed baseline | 5/0, actual execution |
| Fixed new-source empty locale directory | 5/1, actual directory-guard failure with configuration cache reused |
| Fixed existing debug-root empty `drawable-b+te+IN` | 5/1, actual directory-guard failure |
| Ordinary empty `raw` directory in new source root | 5/0, actual execution; removing it restored matching cached success |
| Default XML comment containing U+0939 | 5/1, actual content-guard failure; `processDebugResources` remained UP-TO-DATE (`mergeDebugResources` executed) |
| Raw build script changed to duplicate `setOf("en", "en")` | Runtime set semantics unchanged; 5/1, actual syntax-guard failure; resource/Kotlin tasks remained UP-TO-DATE |
| Supported `:app:cleanTestDebugUnitTest`, then unchanged run | FROM-CACHE valid 5/0 restoration |
| Previously unseen empty source root after cache restore | 5/1, actual directory-guard failure, configuration cache reused |
| All mutations restored | 5/0 FROM-CACHE; unchanged runs UP-TO-DATE |

The five post-fix negative probes each failed only the intended test, with zero errors/skips. Expected negative probe exits are evidence, not a failing final source. Cached restorations are explicitly not fresh test execution. No full clean, cache disablement or forced rerun was used to obtain those post-fix failures.

Local raw logs, per-run commands/source hashes/exit receipts and archived JUnit XML are under `outputs/claude-intake-20261008/english-verification` outside the public repository. The two small runner/probe scripts are beside that directory. The same synthetic mutations and focused command above reproduce the checks in an isolated checkout; remove each mutation before the next.

## Full verification and reviews

Frozen-source command `PRECHECK_LOOSE=1 gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain` completed at 07:58 UTC with exit 0: **2,989 tests / 350 suites / 0 failures / 0 errors / 0 skips**, lint **0 errors / 87 warnings / 2 hints**, debug APK assembled. The full test task executed; its input hashes match the probed candidate. Synthetic CI placeholder configuration was used, not production credentials. Release/R8 validation is delegated to hosted CI; no local signed/release assembly is claimed.

The initial standalone design-ratchet command encountered Windows cp1252 output encoding (`UnicodeEncodeError` printing a checkmark); it is a failed tooling invocation, not a design finding. Repeating with Python `-X utf8` succeeded without source, baseline or rule changes.

Independent final [critic](helper-reviews/codex-20261008/english-critic.md) and [QA](helper-reviews/codex-20261008/english-qa.md) each score **9.6/10 for the complete local English-only plus cache-input scope**, with no unresolved mandatory source/test blocker. Both independently inspected raw probes, archived full JUnit and lint evidence, unchanged frozen source, and corrected continuity wording. They did not run Gradle themselves. Historical QA revision `00a30ef5` does not resolve in the fetched branch; its reported score is not transferred to this candidate. Fresh final reports bind to `60579c47` and the app tree above. The shared slot was released at 08:02 UTC after the Gradle daemon and test workers exited.

Hosted Android, golden verification and Gitleaks passed on the original English head `d8f85fcf`, as well as the two original stacked branch heads. Those results do not accept this follow-up. Its own hosted checks and the final combined English target remain integration gates. No release-signed artifact or device/TalkBack validation is claimed.

## Integration and remaining boundaries

Push only the owned branch, proposing the complete English revision to main. It includes the original English commits and supersedes PR1912 after acceptance; a merge preserving that ancestry lets the other branches retain their common base. Do not push to Claude's branches directly. Integrate through the reviewed PR after exact-source evidence and the required independent reviews/checks. English remains first; retarget/reconcile region and reliability after the English main integration. No migration, dataset seed or production operation belongs to this follow-up.

The resource guard intentionally covers conventional `src/*/res` and a constrained Gradle expression, not arbitrary Kotlin execution, custom resource roots or proof of every sentence's language. If those source conventions change, update scanner and cache inputs together. Existing format-locale robustness tests, `translatable=false` markers, application accessibility and signed/device release evidence are separate scopes. Website work stays paused.
