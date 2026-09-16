# Handoff — 2026-09-16 — UX uplift Phase 0 (branch `ux/phase0-safety-net`)

Session ran on the founder's Mac against a fresh clone of `main` (`fe463756`). Nothing was pushed to
`main`, `ops/*`, `codex/*` or `claudedev-*`; the Codex/claudedev renewal branches were not touched (the
founder's standing instruction of 2026-09-16: work on a different branch).

## State
- `main` verify bar re-run locally before any change: **BUILD SUCCESSFUL — 2,791 tests / 0 failures,
  lintDebug 0 errors, assembleDebug** (23 min cold on an 8 GB Mac).
- Branch `ux/phase0-safety-net` = main + 4 round commits (U01, U03, U02, U04) + this doc. PR opened
  against `main`; CI (`android`, `roborazzi verify`, `secret-scan`) runs on the PR.
- **Goldens are NOT committed yet — by design.** Recording must happen on the Linux runner:
  GitHub → Actions → `roborazzi` → Run workflow → branch `ux/phase0-safety-net` → `record = true`.
  The bot commits `app/src/test/snapshots/roborazzi/` to the branch; every later PR is then diffed
  against them. Until that dispatch, the `verify` job skips with a warning.
- Separate fix PR **#1869** (`fix/cron-daily-storage-snapshot-timeout`): `cron-tick-daily` has been red
  every day since 2026-09-07 on the single slot `db-storage-snapshot` (SQLSTATE 57014, 8 s REST statement
  timeout). The PR carries Codex's round3822 migration byte-for-byte (30 s function-local
  `statement_timeout`). Needs the founder: `supabase link --project-ref eyswaywvtartpvtoxtdr`,
  `supabase db push --dry-run` (expect that one file), `supabase db push`, then watch the next 03:00 UTC run.

## Shipped this session (all on `ux/phase0-safety-net`)
| round | what | proof |
|---|---|---|
| U01 | Roborazzi 1.74.0 + preview-scanner: every `@Preview` under `designsystem/` is generated into a Robolectric screenshot test (NATIVE graphics, sdk 35, Pixel 5, vanilla `Application`). `roborazzi.yml` verify/record jobs. `scripts/ci/seed-local-config.sh`. | first run failed booting `EquipSevaApplication` (Hilt → SupabaseClient on the JVM); fixed by `application = android.app.Application::class` in `robolectricConfig`; Pill goldens rendered correctly (all 8 kinds). |
| U03 | `scripts/verify/design_lint.py` + `design_lint.baseline.json`; `android.yml` step before `assembleDebug`; `scripts/README.md`. | baseline at HEAD: raw .dp 2350 · .sp 666 · fontSize= 634 · RoundedCornerShape( 386 · spinners 72 · legacy imports 62 in 10 files (legacy-only: `KycStatusTimeline`) · raw M3 buttons 61 · OutlinedTextField 46 · hardcoded Text 2. Self-test: lowering a baseline number by 1 → exit 1. |
| U02 | 80 `@Preview` in 39 design-system files (`<Stem>Gallery()` + `"<Stem>"` + `"<Stem> large text"` @1.3f). Skipped: 4 `ModalBottomSheet` components, `SecureScreen`, `AdaptiveWidth`. | 44 writer agents + 44 adversarial reviewers (compile-by-inspection, coverage, additive-only diff); then one real compile. |
| U04 | 7 money-path screens pinned: `MyBids`, `HospitalActiveJobs`, `Earnings`, `ActiveWork`, `Conversations`, `Dsr` split into `<Name>Content(state, callbacks…)` + `<Name>ScreenScreenshotTest` (loading/empty/error/populated); `RequestSent` (stateless, 2 states). | reviewers proved identical composable trees; all relative-time inputs nulled so goldens don't drift with the clock. |

Local record run on the whole branch (macOS, goldens discarded — Linux records the real ones):
`:app:testDebugUnitTest -Proborazzi.test.record=true --tests "com.github.takahirom.roborazzi.*" --tests "*ScreenshotTest"`
→ **107 tests / 0 failures** in 3 min: 80 generated preview tests + 27 fixture states
(`MyBids` 5 incl. the Accepted tab, `HospitalActiveJobs` 4, `Earnings` 4, `ActiveWork` 4, `Conversations` 4,
`Dsr` 4, `RequestSent` 2). Spot-checked PNGs render real content (pills, cards, chips, empty states).

## Gotchas learned (keep)
- `robolectricConfig` values are pasted verbatim into `@Config(...)`; without `application` Robolectric
  boots the prod Application and the Hilt graph dies on `SettingsSessionManager`.
- `recordRoborazziDebug`/`verifyRoborazziDebug` are lifecycle aliases and do not take `--tests`; the
  workflows call `:app:testDebugUnitTest -Proborazzi.test.record=true --tests …` instead.
- Roborazzi verify throws on a preview/fixture with **no** golden (`CaptureResult.Added`), so a new preview
  ⇒ dispatch the record job in the same PR.
- Preview `name` becomes part of the golden filename; keep it ASCII (the first draft used an em-dash,
  renamed to `"<Stem> large text"`).
- Two Gradle builds at once on this Mac is not viable; a detached build worktree (`equipseva-ux-build`)
  was used to verify commits while agents edited the main worktree.

## Merge-conflict watch
The Codex branch `codex/auth-integration-20260911` edits `EsBtn.kt`, `EsField.kt`, `EsDropdown.kt`,
`OtpDigitField.kt`, `PrimaryButton.kt`, `Theme.kt`, `Type.kt`, `Typography.kt`, `Shape.kt`, `EsTokens.kt`
and `android.yml`. U02 only *appended* previews to the component files and U03 inserted one step into
`android.yml`, so the conflicts will be trivial (take both sides), but they will exist.

## Next (resume here)
1. Founder: dispatch `roborazzi` with `record=true` on the branch → goldens land → PR CI fully green → merge.
2. Founder: apply PR #1869 (`supabase db push`) — stops the daily cron noise.
3. Phase 1 starts at **U05** (`Theme.kt` → Seva roles). The Codex branch also touches `Theme.kt`; agree the
   merge order first (their theme work is a "reviewed theme milestone" per their handoff).
4. Deferred U04 screens (`HomeHub`, `RequestService`, `RepairJobs` (needs a GoogleMap fake),
   `EngineerDirectory`, `RepairJobDetail`) get their split + fixture inside U17/U18/U27/U21/U22.
5. Phase 1 U16 should give the four modal sheets a stateless `*SheetContent` so they can join the gallery.
