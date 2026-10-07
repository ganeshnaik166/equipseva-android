# Handoff — WP18.T01 English only on main (Claude, 7 October 2026)

Status: **locally verified and independently reviewed (critic 9.7/10, QA 9.6/10, no blockers); not merged. Merging to `main` needs the owner's go-ahead.** Resume point: [CURRENT_STATE.md](CURRENT_STATE.md).

## Why this slice

The owner decided on 23 September 2026 that the product is English only: no Hindi/Telugu translations, words, locale resources or language pickers. Main `49c163eb` still shipped `values-hi`/`values-te`, which were mostly verbatim English copies: at base, 721 of 756 keys in each matched English, so Hindi/Telugu devices saw a mixed partial translation. Main also kept `StringsParityTest`, which forced every new string to be copied three times, and filtered locales to `en`, `hi`, `te`. Every later change that adds or edits strings depends on this landing first.

## Change

Branch `claudedev-english-only-20261007`, from fetched main `49c163ebfe9bacc6b693b95a5218c9c1ac749dd8`. Verified code head **`6460ee89c49545154cb0cd3dc8b860f254d413ca`**.

| Commit | What |
|---|---|
| `9a6376f3` | Scope and ownership recorded in CURRENT_STATE before coding |
| `175bb422` | `EnglishOnlyResourcesTest` with five guards (RED on main) |
| `a47103e2` | Deletes `values-hi/`, `values-te/` and `StringsParityTest.kt`; sets `androidResources { localeFilters += setOf("en") }` so dependency translations are stripped too |
| `b7df80e6` | Closes the gaps the critic found in the guards (details below) |
| `6460ee89` | Replaces the stale round-514 "translation seed" comment in `values/strings.xml`. Comment only: no key or value changed |

The guards, after hardening:

1. No locale-qualified directory of any resource type (`values-hi`, `drawable-hi`, `raw-te`, `xml-b+te+IN`, …) in any source set (`src/main/res`, `src/debug/res`, …). Unknown qualifiers fail closed; `tv` is a language code, not a UI mode.
2. The default catalogue is real: at least 500 unique named strings.
3. `app/build.gradle.kts` has exactly one active `localeFilters += setOf("en")`, directly inside `androidResources`. Comment/string decoys, appended locales, dead `if`/`run` blocks and the deprecated `resourceConfigurations` are rejected.
4. No Devanagari (U+0900–097F) or Telugu (U+0C00–0C7F) code point in any resource XML. This covers literal characters, numeric character references and the Unicode escapes aapt decodes at build time.
5. No script-named font file.

Provenance: commits `175bb422` and `a47103e2` carry the test file and build-script change byte-for-byte from the English candidate Codex prepared test-first on 1 October. That candidate re-applied Claude's original `a6e58067` from `claudedev-build-20260923`. The cherry-picked source commit `ac202816` lives in a private local checkout with no remote, so the trailer naming it cannot be followed on GitHub. Only these source commits were ported; nothing else from that checkout was taken.

Deliberately unchanged:
- The nine `translatable="false"` markers in `values/strings.xml` (forgot-password and Welcome strings). They are now redundant and can be dropped with the owner's agreement.
- `razorpay_api_key`.
- Tests that set a `hi-IN` default `Locale`. They check number and date formatting on phones whose system language is Hindi, which English-only resources do not prevent.
- `ForgotPasswordReceiptUiTest`'s fallback check, which still holds: hi/te devices now fall back to English.

## Evidence

| Check | Result |
|---|---|
| Guard on main plus the test commit only (RED) | **5 tests / 3 failures**: the locale directories, the `localeFilters` line and native script. The catalogue and font guards pass |
| Full bar on the port (`a47103e2`) | `PRECHECK_LOOSE=1 ./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain` exit 0: **2,989 tests / 350 suites / 0 failures / 0 errors / 0 skipped**, lint **0 errors / 86 warnings / 2 hints**, debug APK built |
| Hardening probes (temporary files, removed) | A `src/debug/res/raw-te` directory failed only the directory guard (**5/1**). An escaped U+0939 string in `src/debug/res/values` failed only the native-script guard (**5/1**) |
| Full bar on the final head `6460ee89` | Same command, exit 0: **2,989 / 350 / 0 / 0 / 0**, guard **5/0**, lint **0 errors / 86 warnings / 2 hints**. The unit-test task was then re-executed with `--rerun` on the same head: **2,989 / 0** |
| Diff hygiene | 7 files, +333 / −1,993 against main; identical with whitespace ignored (no line-ending churn). Under `res/`, only `values/strings.xml` was edited (comment only) besides the two deletions |

## Reviews

- **Critic:** **9.5/10** on the port with no blockers, then **9.7/10** on the whole scope after the hardening, with no blockers. Remaining notes are deliberate edge cases only: a dead *outer* block around `androidResources`, an escape check that fails safe slightly broadly, and custom `res.directories` (none exist today).
- **QA:** **9.6/10** on `00a30ef5`, with no blockers. QA re-ran the guard 5/0 and ran its own probes: a `values-hi` and an empty `drawable-b+te+IN` directory, a literal character in an XML comment, and hex and decimal character references in a string and an attribute. Each was caught by the right guard only, and all probes were removed.
- **Head after review:** QA found that three test literals in `00a30ef5` had been written as raw characters rather than Kotlin escapes. The final head `6460ee89` writes them as escapes; this compiles to identical classes. The two follow-up commits were rebuilt locally before the first push.

## Not done / next

- **Merge to main needs the owner's go-ahead.** Open a PR from `claudedev-english-only-20261007` to `main`; hosted Android/goldens/Gitleaks checks then run on the PR head.
- Later string-changing work no longer needs `translatable="false"` markers or Hindi/Telugu copies. Removing the nine existing markers is a separate, owner-approved cleanup.
- QA noted that the guard reads source files Gradle does not track as test inputs. With the local build cache, an edit that leaves compiled resources unchanged (a comment, an empty directory) could be served from cache. A clean CI run always executes it. Declaring `src/*/res` as test inputs would close this; it was out of scope here.
- Older plans still mention Hindi/Telugu work (`docs/ROADMAP_v05.md`, `docs/UX_UPLIFT_PLAN.md`), but the standing decision in [AGENTS.md](../AGENTS.md) overrides them.
- Device and TalkBack checks, signed release and store listing languages are separate release gates.
