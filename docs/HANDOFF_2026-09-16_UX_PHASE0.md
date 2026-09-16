# Handoff — 2026-09-16 — UX uplift Phase 0 (branch `ux/phase0-safety-net`)

Session ran on the founder's Mac against a fresh clone of `main` (`fe463756`). Nothing was pushed to
`main`, `ops/*`, `codex/*` or `claudedev-*`; the Codex/claudedev renewal branches were not touched (the
founder's standing instruction of 2026-09-16: work on a different branch).

## State
- `main` verify bar re-run locally before any change: **BUILD SUCCESSFUL — 2,791 tests / 0 failures,
  lintDebug 0 errors, assembleDebug** (23 min cold on an 8 GB Mac).
- **PR #1870 merged to `main`** (rebase; CI green: android 2,898 tests, roborazzi verify, gitleaks) =
  4 round commits (U01, U03, U02, U04) + this doc + a one-line `roborazzi.yml` quoting fix (`7a165a3a`).
- **Goldens recorded on Linux and committed by the bot** (`6ec8a095`, 107 PNGs = 80 previews + 27 screen
  states) via Actions → `roborazzi` → Run workflow → `record = true`. From here on the `verify` job diffs
  every PR/push touching `app/**` against them. Re-record the same way after any intentional visual change.
- **PR #1869 merged and applied to prod.** `cron-tick-daily` had been red daily since 2026-09-07 on the
  single slot `db-storage-snapshot` (SQLSTATE 57014: the `authenticator` role runs with
  `statement_timeout=8s` and the sweep walks `pg_total_relation_size()` over 4,876 public tables).
  round3822 (`ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout = '30s'`) was
  applied through the Management API — `supabase link --project-ref eyswaywvtartpvtoxtdr` (no DB password
  needed) + `supabase db query --linked -f <migration>` — and recorded in
  `supabase_migrations.schema_migrations` so a later `db push` skips it. Proof through the real path:
  `cron-tick-daily.yml` now takes a `slot` dispatch input; `slot=db-storage-snapshot` → `ok: true`,
  4,876 rows in 13.9 s (> the old 8 s), `cron_tick_runs` id 135 green, first snapshot batch written.
  The next scheduled daily run (03:00 UTC) should be green end to end.

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
- `--tests` filters must be inline and single-quoted in the workflow `run:` line. Kept in an env var as
  `--tests "x"`, the quote characters reach Gradle inside the pattern and it reports "No tests found"
  (the first record dispatch died that way).
- `workflow_dispatch` only works once the workflow file exists on the default branch — the record job
  could not be dispatched from the PR branch; it ran on `main` after the merge.
- Right after a migration's `NOTIFY pgrst, 'reload schema'` PostgREST reloads for minutes and every
  request fails with PGRST002 (an 8-char code the edge function's SQLSTATE filter drops, so the run shows
  `slot_failed` with no code and no `cron_tick_runs` row). Wait ~3 min before probing.
- Two Gradle builds at once on this Mac is not viable; a detached build worktree (`equipseva-ux-build`)
  was used to verify commits while agents edited the main worktree.

## Merge-conflict watch
The Codex branch `codex/auth-integration-20260911` edits `EsBtn.kt`, `EsField.kt`, `EsDropdown.kt`,
`OtpDigitField.kt`, `PrimaryButton.kt`, `Theme.kt`, `Type.kt`, `Typography.kt`, `Shape.kt`, `EsTokens.kt`
and `android.yml`. U02 only *appended* previews to the component files and U03 inserted one step into
`android.yml`, so the conflicts will be trivial (take both sides), but they will exist.

## Part 2 (same day, after the founder's "carry on") — branch `ux/u13-u15-radius-spacing-navlabels`
| round | what | proof |
|---|---|---|
| U13a | `EsRadius`/`Spacing` tokens on `MyBids`, `HospitalActiveJobs`, `Earnings`, `ActiveWork`, `EngineerActiveEscrows` (the money-path files the Codex branch does not touch). Same-value swaps only. | 107/107 goldens byte-identical before/after on the same machine (sha256). Ratchet: raw `.dp` 2350 → 2265, `Spacing.*` 83 → 156, `EsRadius.*` 0 → 12; baseline refreshed in the commit. |
| U15 | Bottom-nav labels → `R.string.nav_*` (en/hi/te), `tabsForRole` now `@Composable`. | parity 759/759/759; `EsBottomNav` golden identical. |
| i18n fix | 111 double-encoded string entries repaired (45 hi, 45 te, 21 en: arrows, `·`, `—`). Detector + repair: `text.encode('latin-1').decode('utf-8')` per `<string>`/`<item>` body, formatting untouched. | 0 mojibake markers left; XML parses; all 107 goldens still byte-identical (none renders a repaired string). |

Also: `docs/AGENTS_READ_FIRST.md` + README pointer + issue **#1871** tell every other agent to rebase onto `main` and read
this file before resuming.

Golden renders changed by the glyph repair: **none** — re-rendered all 107 with the repaired resources on the same
machine, byte-identical (none of the 111 repaired strings is on a pinned screen or design-system preview). No
re-record needed after this merge.

## Part 3 (overnight, founder asleep — "carry on for 2 hours, no questions")
| item | what | proof |
|---|---|---|
| web console (PR #1873, merged) | `web/` typecheck 9,734 → 0. Root cause: 125 generated founder pages use `{ header, accessor }` / `{ header, cell }` columns that `DataTable`'s `Column<T>` never declared — type errors AND every cell on those pages rendered "—" (`row[undefined]`). `Column<T>` is now keyed \| accessor \| cell; residual 106 fixed (dead `?? i`, missing `await`, `label:`→`header:`, explicit `<DataTable<RowType>>`). `npm test` render smoke test wired into `web.yml`. | web CI green: typecheck ✓, smoke ✓, `next build` of 3,005 routes ✓ (4m57s). A red `web` run is a real regression from now on. |
| U22a | `RepairJobDetailScreen` → thin wrapper + `RepairJobDetailContent(state, actions, …)` + `RepairJobDetailActions` (37 members) + 9 fixture states. | compile clean, 116/116 screenshot tests render locally. |
| U22b | 30 composables moved verbatim into `repair/detail/sections/*` (7 files) + `repair/detail/sheets/*` (7 files); helpers stay in place (tests import that package). | all **116** goldens (107 existing + the 9 new detail states) byte-identical before/after on the same machine; screen file 3,584 → 1,263 lines; compile clean; ratchet unchanged. |
| CI hygiene | `android.yml` `pull_request` now has the same `paths-ignore` as `push` (docs/web/website-only PRs skip the 19-min build). | |
| U23a (PR #1875) | Job-detail `HospitalBanner`: site name gets `weight(1f, fill = false)` so the "Verified" badge no longer wraps letter-by-letter next to long names. | local before/after: exactly the 6 banner-bearing detail goldens changed, 110 identical; Linux record dispatched on the PR branch (works now that `roborazzi.yml` is on `main`). |

Merge point with Codex: their branch adds 3 lines to `RepairJobDetailScreen.kt` (`import …LightEsColors` + `contentColor = LightEsColors.text` in one section) — after U22b that section lives in `repair/detail/sections/…`; port the two lines there when merging.

## Next (resume here)
1. After the U22 PR merges: Actions → `roborazzi` → `record = true` on `main` (9 new `RepairJobDetailScreen_*` goldens);
   close issue #1871 once the other branches have rebased.
2. Confirm tomorrow's 03:00 UTC `cron-tick-daily` is green (`select id, slot, ok, failed_slots from
   public.cron_tick_runs order by id desc limit 3` via `supabase db query --linked`).
3. Phase 1 starts at **U05** (`Theme.kt` → Seva roles). The Codex branch also touches `Theme.kt`; agree the
   merge order first (their theme work is a "reviewed theme milestone" per their handoff).
4. Deferred U04 screens (`HomeHub`, `RequestService`, `RepairJobs` (needs a GoogleMap fake),
   `EngineerDirectory`, `RepairJobDetail`) get their split + fixture inside U17/U18/U27/U21/U22.
5. Phase 1 U16 should give the four modal sheets a stateless `*SheetContent` so they can join the gallery.
