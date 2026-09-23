# Agents: read this before you continue (updated 2026-09-16)

> **Current resume point:** [CURRENT_STATE.md](CURRENT_STATE.md) and
> [MILESTONE_LOG.md](MILESTONE_LOG.md). Follow the repository [AGENTS.md](../AGENTS.md)
> entry/save contract; the dated tables below retain historical implementation evidence.

> **English only (owner decision 23 September 2026):** no Hindi/Telugu translations, words or locale resources anywhere in the product. `values-hi`/`values-te` are removed on `claudedev-build-20260923`; the en/hi/te rules quoted in older tables below are historical. See [AGENTS.md](../AGENTS.md).

> **Product direction updated 19 September 2026:** read
> [PRODUCT_PLAN.md](../PRODUCT_PLAN.md) and the
> [delivery ledger](product-plan/DELIVERY_LEDGER.md) first. They govern the new
> three-choice registration, scoped paid engineering-team workspaces, synthetic
> demo and district-based/no-map target. Earlier implementation notes below are
> historical, not permission to retain obsolete product decisions. Preserve the
> selected lime/ink theme and all existing security, test and release gates.

`main` moved on 2026-09-16. If your branch (`codex/*`, `claudedev-*`, or anything older than `ee885deb`)
was cut before that, rebase or merge `main` **before** you build on your own handoff, and read
[`HANDOFF_2026-09-16_UX_PHASE0.md`](HANDOFF_2026-09-16_UX_PHASE0.md) for the details. Founder's rule:
nobody takes over a workstream without first checking the progress recorded here.

## What landed on `main` (all CI-green, all merged)
| what | where | why it affects you |
|---|---|---|
| **Roborazzi screenshot tests** — every `@Preview` under `designsystem/` is a generated Robolectric test; 7 money-path screens have `*ScreenScreenshotTest` fixtures; 107 goldens committed under `app/src/test/snapshots/roborazzi/` | PR #1870 (U01/U02/U04), goldens `6ec8a095` | Any PR/push touching `app/**` runs `.github/workflows/roborazzi.yml` → **verify fails if your change alters a pixel of a design-system component or of those screens, or adds a `@Preview` without a golden.** Intentional visual change ⇒ Actions → `roborazzi` → Run workflow → `record = true` (Linux only — never commit locally rendered PNGs). |
| **Design-lint ratchet** in `android.yml` | `scripts/verify/design_lint.py` + `design_lint.baseline.json` (U03) | CI fails if raw `.dp`/`.sp`/`fontSize=`/`RoundedCornerShape(`/raw M3 `Button`/`TextField`/`CircularProgressIndicator`/legacy theme-token imports/hardcoded `Text("` counts in `features/` rise above the baseline. Run it locally: `python3 scripts/verify/design_lint.py`. Refresh the baseline only in a commit that lowers the numbers. |
| **Screen → Content splits** | `MyBidsScreen`, `HospitalActiveJobsScreen`, `EarningsScreen`, `ActiveWorkScreen`, `ConversationsScreen`, `DsrScreen` now delegate to `internal <Name>Content(state, callbacks…)` | If you edit those screens, keep the wrapper thin and put UI in `<Name>Content`; the fixture tests construct `Content` directly. |
| **`@Preview` galleries appended** to 39 design-system files | `<Stem>Gallery()` + two private previews at the END of each file | Your edits above the previews merge cleanly; if you change a component's signature, its gallery must compile too. |
| **cron-tick-daily fixed in prod** | PR #1869 (round3822 `statement_timeout=30s` on `db_storage_snapshot_sweep()`, applied via `supabase db query --linked`); `cron-tick-daily.yml` gained a `slot` dispatch input | Do not re-apply round3822 (it is in `supabase_migrations.schema_migrations`). Rounds 3821/3823 on the Codex branch are still **unapplied**. |
| **Web console CI is a real gate again** — `npm run typecheck` 9,734 → 0 errors; `DataTable` accepts the keyed / `accessor` / `cell` column shapes; `npm test` render smoke test | `web/src/components/DataTable.tsx`, `web/scripts/datatable-smoke.tsx`, `.github/workflows/web.yml` | A red `web` run is now a real regression, not "old debt". Inline `columns={[…]}` with per-column param annotations breaks inference — pass `<DataTable<RowType> …>` (see `web/README.md`). |
| **`RepairJobDetailScreen` decomposed** (U22a/b, PR #1874) — thin wrapper + `internal RepairJobDetailContent(state, actions: RepairJobDetailActions, …)`; 30 composables now live in `features/repair/detail/sections/*.kt` and `detail/sheets/*.kt` (verbatim moves, `internal`); pure helpers stayed in `RepairJobDetailScreen.kt`; 9 `RepairJobDetailScreen_*` goldens | `features/repair/RepairJobDetailScreen.kt` (3,584 → 1,263 lines), `RepairJobDetailActions.kt`, `detail/**` | **Codex branch:** your `LightEsColors` `contentColor` lines in the old file now belong in the matching `detail/sections/*.kt`. New ViewModel methods the UI calls must be added to `RepairJobDetailActions` (+ `asActions()` + `NoOp`). Editing a section changes its golden → re-record. |
| `android.yml` PR trigger now skips docs/web/website-only PRs (same `paths-ignore` as push) | `.github/workflows/android.yml` | no 19-minute Android build on a docs-only PR. |
| `scripts/ci/seed-local-config.sh` | shared CI seeding of `local.properties` + placeholder `google-services.json` | use it instead of copy-pasting the heredocs. |

## Known merge points with `codex/auth-integration-20260911`
Both sides touched `EsBtn.kt`, `EsField.kt`, `EsDropdown.kt`, `OtpDigitField.kt`, `PrimaryButton.kt`, `Theme.kt`
(only via previews/gallery on the `main` side), `android.yml` (one inserted step on `main`),
`ConversationsScreen.kt`, `DsrScreen.kt`, `RequestSentScreen.kt` (Screen/Content split on `main`),
`MainNavGraph.kt`. Conflicts should be "keep both"; after resolving, run the ratchet and the screenshot
tests (`./gradlew :app:testDebugUnitTest --tests 'com.github.takahirom.roborazzi.*' --tests '*ScreenshotTest'`)
before pushing.

## Where the UX program stands
Phase 0 (U01–U04) is **closed**. Next open round is **U05** (`Theme.kt` → Seva colour roles). The Codex
branch carries its own reviewed theme work — settle the order (theirs first, then U05 on top, or the
reverse) before anyone edits `Theme.kt` again. Source of truth: [`UX_UPLIFT_PLAN.md`](UX_UPLIFT_PLAN.md).

## Branch rule
`main == ops/r1388-calendar-burndown` (fast-forwarded together). Ship via PR to `main` (CI runs there), then
fast-forward `ops`. Do not push to another agent's branch.
