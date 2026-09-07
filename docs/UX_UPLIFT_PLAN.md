# EquipSeva UX/UI uplift — plan + operating prompt

> Drafted 2026-09-07 at HEAD `5b09bb7b` (branch `ops/r1388-calendar-burndown`, prod through round3819).
> Author: Claude (acting PM/CEO/QA per the founder's standing delegation). Founder: Ganesh Dhanavath.
>
> This is the source of truth for the UX/UI program. Every uplift session starts by reading this file,
> picks up at the first unchecked round, and updates the checkboxes + numbers when it ships.

---

## 0. Why now

The correctness layer of UX is done: ~62 state-mislabel / dead-CTA / format bugs (rounds 1457–1473),
49 state-handling anti-patterns, 29 server error codes mapped to friendly copy, serial-load perf, and the
round 3770–3819 feature surfacing are all shipped and test-locked. What a user *feels* has not had a pass:
two visual languages coexist, the app is static (zero motion), spinners instead of skeletons, banner
fatigue on Home, a 3,551-line job screen, hidden accessibility debt, and no visual-regression safety net.
That is the next layer. This program is behaviour-preserving by design: it changes how the product
looks, moves, and guides, not what it does.

## 1. Measured baseline (re-run `scripts/verify/design_lint.*` once Phase 0 lands)

| Signal | Value at HEAD | Read |
|---|---|---|
| Screens / feature files / feature LOC | 84 / 147 / ~56 k | big surface; prioritise the money path |
| Design-system files / LOC | 55 / 5,263 | solid base (Es* components, Seva tokens, Motion, Spacing, EsRadius) |
| Feature files on Seva tokens / legacy tokens / legacy-only | 93 / 48 / 5 | token migration ~⅔ done; legacy-only: `RequestServiceScreen`, `KycStatusTimeline`, `ProfileForms`, `LocationPickerMap`, `ServiceAreaMap` |
| `MaterialTheme.colorScheme` wired to | **legacy** palette (`BrandGreen`, `AccentLime`, `Ink*`) | M3 widgets and Seva-token screens disagree on colour |
| `EquipSevaShapes` | 5 dp for every M3 slot; `EsRadius` (4/8/12/16) has **0** uses; 386 raw `RoundedCornerShape(` | radius scale unused |
| Raw `.dp` vs `Spacing.*` | 2,351 vs 83 | spacing scale bypassed |
| Raw `.sp` / `fontSize =` vs `EsType.*` / `MaterialTheme.typography` | 666 / 630 vs 226 / 11 | type scale bypassed |
| Raw `Button/TextButton/OutlinedButton` vs `EsBtn` | 126 vs 142 | half-adopted |
| Raw `TextField/OutlinedTextField` vs `EsField` | 93 vs 57 | half-adopted |
| `CircularProgressIndicator` vs skeleton (`ListSkeleton`/`Shimmer*`) | 72 vs 4 | spinners, not skeletons |
| `AnimatedVisibility` / `animateContentSize` / `AnimatedContent` / haptics / `Motion*` tokens | 0 / 0 / 0 / 0 / 0 | the app is static |
| `contentDescription = null` vs meaningful | 131 vs 32 | a11y debt (some nulls are correctly decorative) |
| `@Preview` / `testTag` / screenshot tests | 0 / 0 / none | **no visual safety net** |
| Unit-test files / Compose UI tests (Robolectric) | 334 / 19 | behaviour is pinned; visuals are not |
| i18n | 755 en / 754 hi / 754 te; 3 hardcoded `Text("` | excellent; **bottom-nav labels are hardcoded English** in `MainNavGraph.tabsForRole` |
| Largest screens (LOC) | RepairJobDetail 3,551 (34 composables, 6 sheets) · HomeHub 1,591 · AmcDetail 1,574 · Profile 1,544 · EngineerPublicProfile 1,417 · Kyc 1,345 · CreateAmcWizard 1,186 · RequestService 986 | monoliths on the money path |
| Dead DS components | `PrimaryButton`, `TonalButton` (0 uses) | delete or alias |
| Brand | app = Seva green `#0B6E4F` + glow (Color.kt, from `newdesign.zip:tokens.css`) · website `styles.css` = teal `#00d3c0` · `docs/launch/DESIGNER_BRIEF.md` = teal/blue | three brand languages |
| Dark mode | `ThemeMode` pref exists, default `Light`, **no UI sets it** | dormant, not a defect |
| Bottom nav | Hospital: Home/Bookings/Messages/Profile · Engineer: Home/Jobs/Earnings/Profile | fine; Home is a tile hub + up to 6 stacked banners |

## 2. Diagnosis — what a user feels

1. **Two visual languages.** M3 defaults (legacy green/lime, 5 dp corners, Roboto M3 type) sit next to Seva
   paper/green screens. The hospital's #1 conversion screen (`RequestServiceScreen`) is legacy-only.
2. **Nothing moves.** No screen transitions, no banner enter/exit, no skeleton→content crossfade, no haptics.
   Motion tokens exist and are unused.
3. **Dense monoliths.** `RepairJobDetailScreen` is the heart of both roles' journeys (stepper, bids, escrow,
   DSR, check-in, completion proof, rating, cancel) in one file; hierarchy and the single-primary-CTA rule
   are hard to keep.
4. **Home = chooser + banner stack.** Up to six banners (KYC, directory visibility, phone missing, pending
   AMC payment, pending contract, SLA credits) compete with three tiles; the first-run hospital path has an
   extra hop before "Request service".
5. **Loading feels slow** because 72 spinners replace layout instead of preserving it.
6. **Accessibility is unverified**: TalkBack labels, touch targets, font-scale, and token contrast never audited.
7. **Any uplift is currently unsafe**: zero previews, zero screenshot tests, so visual regressions are invisible
   until an emulator drive.
8. **Brand isn't settled** across app, website, and store assets; the Play screenshots launch blocker
   (LAUNCH_CHECKLIST #9) is still open and can be produced *by* this program.

## 3. Decisions locked (do not re-litigate in later sessions)

- **D1 Brand = Seva green.** `Color.kt`'s Seva scale is canonical (it is sampled from the current logo).
  Website + DESIGNER_BRIEF are stale; re-skin/update them in Phase 4.
- **D2 Dark mode is out of scope.** `ThemeMode` stays `Light`; do not author dark tokens. Colour work
  still goes through semantic roles so dark becomes cheap later.
- **D3 Behaviour-preserving.** No business-rule, RPC-contract, or copy-meaning changes. Pinned tests stay
  green; when copy changes intentionally, update the pin and all three locales in the same round.
- **D4 Priority = the money path**, both roles: post → discover → bid → accept → work (check-in → DSR →
  countersign) → rate → payout. Founder screens last; the web console is a separate track.
- **D5 Token-first + ratchet.** Every touched file ends 100 % on Es tokens/components; a design-lint
  ratchet in CI forbids the raw counts from rising.
- **D6 Material 3 stays the base.** Es* components wrap M3; no new UI framework.
- **D7 Direction lock before code churn.** Phase 1.5 produces a Claude Design canvas of five hero screens;
  the founder glances and says go, or the delegated default proceeds.
- **D8 Backend untouched** unless a UX need is impossible without it; then follow the server-side
  delegation precedent (r1514) with a reviewable migration.

## 4. Workflow — five phases, each a run of r#### rounds

Rounds are labelled U01-U45 below; each takes the NEXT FREE r#### number when it ships (numbers move fast: another session already held round3820 on the day this was written). One commit per round, several rounds per build cycle,
push after every green batch. Each round records **before/after screenshots** (Roborazzi + emulator) in
the commit body or `docs/ux/`.

### Phase 0 — Safety net + measurement (no visual change) · ~1 session

- [ ] **U01** Roborazzi screenshot tests on the existing Robolectric 4.16.1 stack: a design-system gallery
      test that renders every `designsystem/components/*` in every variant/state. Check Maven metadata for
      the current Roborazzi version compatible with AGP 9.2.1 / Robolectric 4.16.1 — do not guess.
      `@GraphicsMode(NATIVE)`, Pixel-class qualifiers, fixed SDK. **Record baselines on the Linux CI runner**
      (a `workflow_dispatch` record job that commits them), never on Windows — font rasterisation differs.
      Local runs use `compareRoborazziDebug` with a small pixel-diff threshold.
- [ ] **U02** `@Preview` on every design-system component (light, default font scale + 1.3).
- [ ] **U03** Design-lint ratchet: `scripts/verify/design_lint.py` (or `.sh`) that counts, per
      `features/`, raw `.dp`, `.sp`, `fontSize =`, `Color(0x`, `RoundedCornerShape(`, raw M3
      `Button/TextButton/OutlinedButton/TextField/OutlinedTextField/CircularProgressIndicator`, legacy token
      names, hardcoded `Text("`; writes `design_lint.baseline.json`; fails when any count rises. Wire into
      `android.yml` before `assemble`. Also count the *positive* signals (Motion tokens, `EsBtn`, `EsField`,
      `Spacing.`, `EsRadius.`, `EsType.`) for the progress table.
- [ ] **U04** Screen fixture screenshots for the 12 money-path screens in loading / empty / error /
      populated states. Where a screen is not yet split into `XScreen(vm)` + stateless `XContent(state,
      callbacks)`, extract `XContent` first (behaviour-preserving, existing tests green).

**Gate:** baselines committed, CI green, ratchet baseline committed, numbers in §1 refreshed.

### Phase 1 — One design language · ~2 sessions

- [ ] **U05** `Theme.kt`: wire `LightColors` to Seva roles (primary `SevaGreen700`, primaryContainer
      `SevaGreen50/100`, background `PaperDefault`, surface white, surfaceVariant `Paper2`, onSurface
      `SevaInk900`, onSurfaceVariant `SevaInk500`, outline `BorderDefault`, error `SevaDanger500`, …).
      Introduce a semantic `EsColors` layer (bg, surface, surfaceRaised, textPrimary/Secondary/Muted,
      border, primary/onPrimary, success/warning/danger/info + their containers) exposed via
      `MaterialTheme` extension or a CompositionLocal. `EquipSevaShapes` → `EsRadius` scale. M3
      `Typography` slots → `EsType`. Screenshot diff review of the gallery.
- [ ] **U06–U09** Retire the legacy palette: alias byte-identical names, migrate the 48 legacy files
      (start with the 5 legacy-only ones; `RequestServiceScreen` first), delete the legacy section of
      `Color.kt`. **Per-file agent fan-out for the mechanical edits (precedent r1467), single-threaded
      review of the screenshot diffs.**
- [ ] **U10–U12** Adopt `EsBtn` for the 126 raw buttons and `EsField` for the 93 raw text fields. First
      extend `EsField` with every needed variant (multiline, password toggle, trailing icon, helper +
      error text, `₹` prefix, read-only). Delete `PrimaryButton`/`TonalButton` or make them thin aliases.
- [ ] **U13** Radius + spacing + type sweep on the money-path screens: `RoundedCornerShape(` → `EsRadius`,
      raw `.sp`/`fontSize` → `EsType`, common paddings → `Spacing`. Targets for the ratchet table:
      raw `.sp` −80 %, `RoundedCornerShape(` in features −100 %, raw `.dp` −60 %.
- [ ] **U14** Skeletons: replace list/detail `CircularProgressIndicator` with `ListSkeleton`/`ShimmerBox`
      shaped like the content; keep spinners only for in-flight buttons.
- [ ] **U15** Bottom-nav labels → string resources (en/hi/te); grep-prove no other hardcoded UI English.
- [ ] **U16** Consistency components that Phase 2 needs: `EsConfirmSheet` (destructive confirmations),
      `EsNextStepCard` (single prioritised action), `EsSectionHeader`, `EsInlineError` (error + retry that
      keeps partial content), `EsStatusTimeline`.

**Phase 1.5 — Direction lock (half a session).** Using the `design` skill, publish a Claude Design canvas of
five hero screens in the unified language: hospital Home, Request Service (equipment step), Job detail with
bids, engineer Jobs board, Check-in/DSR. Hand the founder the link. Proceed on the delegated default if no
reply within the session.

**Gate:** zero legacy token refs in `features/`; ratchet counts down on every dimension; gallery + fixture
screenshots reviewed; on-device smoke on both review accounts, zero crashes.

### Phase 2 — Money-path UX, one screen per round, PM-walk first · ~3–4 sessions

Before touching a screen, walk it as the user (PM lens, precedent 2026-07-18): what is the one thing they
came to do, what blocks it, what is the next step after. Then redesign the hierarchy around that.

Hospital
- [ ] **U17** Home hub: replace the banner stack with one `EsNextStepCard` (priority: phone missing →
      pending AMC payment → pending contract → KYC → first-job CTA); other alerts collapse to a count row;
      quick-action row (Request service · Track bookings · Messages); recent activity below.
- [ ] **U18–U20** Request Service wizard: persistent progress header, draft autosave across process
      death, per-step inline validation, equipment step with recent equipment + a **serial-number nudge with
      "why it matters"** (90 % of jobs are booked without one and the NABH chain is keyed on it — round3814),
      photo step thumbnails + remove, a review step, and a success screen with a what-happens-next timeline.
- [ ] **U21** Bids inbox (in job detail): compare view — sort by price / ETA / rating, verified + tier
      badges, one "recommended" with its reason, accept → confirmation that explains escrow.
- [ ] **U22–U25** `RepairJobDetailScreen` decomposition into `repair/detail/sections/*.kt` and
      `repair/detail/sheets/*.kt` (behaviour-preserving, all tests green, screenshots identical), then
      hierarchy: status stepper as hero, exactly one primary CTA per state in `StickyBottomBar`, secondary
      actions in an overflow, terminal banners consistent.
- [ ] **U26** DSR countersign + rating: a "what you are signing" summary, then rate, then next step.

Engineer
- [ ] **U27** Jobs hub → board: map/list toggle, radius chips, urgency pills, distance + estimated net
      payout on cards, remembered filter.
- [ ] **U28** Bid composer: live net-to-you (commission tier already exposed), ETA picker, validation.
- [ ] **U29** Active work as "Today": next action per job (Check in · Continue DSR · Awaiting
      countersign), travel CTA.
- [ ] **U30** Check-in sheet: photo gate explained up front, location-permission education state,
      distance readout with tolerance, mock-location message that is honest.
- [ ] **U31** DSR form ergonomics: section progress, autosave, tri-state controls with visible labels,
      summary counter, unambiguous "Revise report".
- [ ] **U32** Earnings: payout state timeline (queued → processing → paid), next payout date, breakdown
      that foots (pins exist).

Cross-cutting
- [ ] **U33** Every list has an empty state with a CTA (`EmptyStateView` supports it).
- [ ] **U34** `EsInlineError` replaces full-screen errors wherever partial content exists.
- [ ] **U35** Session-expiry UX: with round3816's refresh in place, retry automatically once, then show
      the expired state with a single "Sign in again" action.
- [ ] **U36** Destructive confirmations via `EsConfirmSheet`; snackbar-with-undo where reversible.
- [ ] **U37** Offline banner + queued-outbox pill consistent across screens.

**Gate per round:** before/after screenshots; on-device drive of the touched step on the relevant role;
adversarial self-review of the diff before commit (precedent: 7 findings caught pre-commit in the DSR round);
copy changes ship with all three locales and updated pins.

### Phase 3 — Feel: motion, feedback, accessibility · ~1–2 sessions

- [ ] **U38** NavHost enter/exit transitions using `MotionDuration.medium` + `MotionEasing.standard`
      (fade + 6 dp slide); bottom nav stays put; respect reduce-motion.
- [ ] **U39** `AnimatedVisibility` on banners / next-step card; `animateContentSize` on expanding cards;
      `AnimatedContent` for skeleton → content; `TapScale` inside `EsBtn`; haptics on success, destructive,
      and confirm.
- [ ] **U40** Live pulse (`pulseLoop`) on "on the way" / "processing" status dots.
- [ ] **U41** Accessibility: meaningful `contentDescription` (decorative stays null), 48 dp targets audit,
      TalkBack drive of the funnel via uiautomator dumps, Roborazzi variants at font scale 1.3 and 2.0,
      WCAG AA contrast check of token pairs (`SevaInk400/500` on `Paper*`/white) with fixes.

**Gate:** motion counters > 0 in the ratchet table; a11y variants green; no layout breaks at 2.0×.

### Phase 4 — Ship-readiness · ~1 session

- [ ] **U42** Full-funnel on-device drive on both review accounts at HEAD; zero crashes;
      `docs/ONDEVICE_VERIFICATION_ux_uplift.md`.
- [ ] **U43** Regenerate the eight Play Store screenshots (1080×1920) from the emulator into
      `play-store/launch-assets/` — closes LAUNCH_CHECKLIST #9.
- [ ] **U44** Update `DESIGNER_BRIEF.md` brand table to Seva green; re-skin `website/styles.css` to the
      Seva tokens if it fits in one round, otherwise open it as a separate track.
- [ ] **U45** Update `APP_FLOW.md` for changed flows; refresh §1 numbers; memory + handoff.

Budget: roughly 45 rounds over 8–10 sessions under the 70 % usage stop rule.

## 5. Rules of engagement (from project memory — binding)

- Work on `ops/r1388-calendar-burndown`; never `main`. Author is Ganesh. One commit per round:
  `feat(ux): round#### — <what changed for the user>` (`refactor(ux)` / `test(ux)` where apt), body =
  why + files + "Green locally: …" + screenshot refs; harness Co-Authored-By trailer.
- Verify bar per batch: `./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --continue`
  plus `compareRoborazziDebug` once Phase 0 lands. Batch several rounds per build; commit each separately;
  push after each green batch. Run long builds in the background.
- Strings: every new string in `values`, `values-hi`, `values-te` (keep 755-parity); literal `%` with no
  args needs `formatted="false"` per locale; never hardcode UI English in Kotlin.
- Icons: `AutoMirrored` for directional glyphs; grep-prove an icon name exists before using it.
- Tests: the 334 test files stay green; change a pin only for an intentional behaviour/copy change and say
  so in the commit; add gallery/fixture screenshots for every touched component/screen.
- Windows gotchas: the Bash tool breaks on heredocs containing apostrophes → write files with the Write
  tool; PowerShell 5.1 has no `&&`; a stale Gradle daemon can drop new files (`gradlew --stop`).
- Emulator: `eqs` AVD; accounts `play-review-hospital` / `play-review-engineer`; driver gotchas in the
  `emulator-verify` memory (coordinate-tap sign-in fields, `keyevent 111` not 4, mock-location recipe,
  system photo picker, no concurrent uiautomator sweeps).
- Usage: stop launching new rounds at 70 % session usage; finish in-flight rounds, commit, push, write the
  handoff + memory.
- Do **not**: re-run the correctness UX audit (done), re-open brand, build dark mode, touch founder screens
  before Phase 4, restyle the web console, add libraries beyond Roborazzi, replace Material 3, or change
  RPC contracts/migrations for cosmetic reasons.

## 6. Prompts

### 6.1 Master prompt (paste into a fresh Claude Code session in this repo)

```
You are the founder-delegated PM/design lead/engineer for EquipSeva (Android, Jetpack Compose + Supabase,
two-sided marketplace: hospitals book verified biomedical engineers). Run the UX/UI uplift program.

First read, in order: docs/UX_UPLIFT_PLAN.md (source of truth), then the memory files it references
(emulator-verify, ship-workflow, ci-android-workflow, usage-limit-stop-rule). Re-verify the §1 baseline
numbers with a 2-minute grep before changing anything; correct the table if they drifted.

Then execute the plan starting at the first unchecked round, in order, one commit per round, batching
rounds per build cycle, pushing after every green batch. Behaviour-preserving throughout: no business-rule,
RPC-contract, or copy-meaning changes; pinned tests stay green; intentional copy changes ship with en/hi/te
and updated pins in the same round.

Non-negotiables: branch ops/r1388-calendar-burndown only; verify bar = testDebugUnitTest + lintDebug +
assembleDebug (+ compareRoborazziDebug once it exists); every touched file ends 100 % on Es tokens and Es
components; every round records before/after screenshots; adversarial self-review of each diff before
committing; decisions D1–D8 in the plan are settled, do not re-open them.

You may use a workflow / fan out agents for the mechanical steps (per-file token and component migration,
fixture extraction); keep redesign judgement single-threaded. When Phase 1.5 arrives, publish the Claude
Design canvas and hand me the link, then continue on the delegated default.

Check session usage roughly every 20 minutes; at 70 % stop starting new rounds, finish what is in flight,
commit, push, tick the checkboxes and refresh the numbers in docs/UX_UPLIFT_PLAN.md, update memory, and
write docs/HANDOFF_<date>.md with the exact next round. End with a short recap: rounds shipped, what a
user now sees differently, what is next.
```

### 6.2 Continuation prompt (every later session)

```
Continue the EquipSeva UX/UI uplift. Read docs/UX_UPLIFT_PLAN.md and the latest docs/HANDOFF_*.md, confirm
CI is green at HEAD, then resume at the first unchecked round under the same rules (one commit per round,
behaviour-preserving, screenshots, 70 % stop, plan + memory updated before you stop).
```

### 6.3 Single-screen prompt (when the founder wants one screen fixed now)

```
UX pass on <ScreenName> only, per docs/UX_UPLIFT_PLAN.md §2 + §5: PM-walk it first (the one thing the user
came to do, what blocks it, the next step), then redesign hierarchy to a single primary CTA, Es tokens and
components only, skeleton loading, empty/error states with a CTA, motion tokens for enter/exit, meaningful
content descriptions, en/hi/te for any copy. Behaviour-preserving; screenshots before/after; one commit
`feat(ux): round#### — …`; drive it on the emulator on the relevant role before you push.
```
