# UI-02 shared-action slice

Follows UI-01 candidate `be8f42a1322fc8ca906fe951af45d57feb13f773` on
`codex/auth-integration-20260911`. This is the primary-action part of UI-02;
fields, cards, sheets, navigation, feedback components and page redesigns are
not all completed by this slice. This bounded slice is locally accepted at
`c7da5ee333d3913bf98052c9c20f81b3b56f6d38`:
[final evidence](../evidence/ui-foundation/README.md).

## Changes and ownership

- `PrimaryButton` uses the lime/ink pair, readable disabled pair, a 52dp minimum
  that grows with its label, and 12dp vertical padding. Loading retains the label,
  rejects taps, uses a readable spinner and a separately localized state
  description in English/Hindi/Telugu. It does not replace the label's semantics
  with a duplicate English content description.
- `EsBtn` keeps its existing named parameters and adds an optional foreground
  override for known fixed-surface callers. Material's Button provides focus,
  button/disabled semantics and click behavior. All six kinds use paired roles;
  Sm secondary targets have a 48dp minimum, primary kinds at least 52dp.
- Compact actions keep intrinsic width. Full-width text gets a full-width
  paragraph; compact text uses start alignment inside the centered content group
  to avoid a centered paragraph wider than its measured text box.
- Buttons use 26dp capped corners: capsules at normal height, growing rounded
  rectangles at large text. Ink focus strokes are 3dp inside the lime fill, where
  ink is distinguishable even on an inverse/dark parent. Icons retain space on
  both sides of long labels.
- Eight Ghost callsites were traced. Only RequestSent's white footer,
  Supervision's white assignment card and RepairDetail's PaperDefault invoice
  action get an explicit light foreground. The other five are on themed modal
  sheets and retain their dynamic pairing. Callback/state/navigation expressions
  were not changed.
- `EsActionGroup` wraps compact actions with 8dp gaps. Three payout action groups
  use it after a source-like Row reproduction hid the last action at 320dp and
  twice text size. Mark-paid/cancel sheet bodies scroll with navigation/IME
  padding. Existing callbacks, enablement and payment ownership remain intact;
  this is layout recovery, not acceptance of a payment workflow.

## Verification record

- Red baseline of old shared actions: 6 tests, 6 expected assertions failed:
  physical 44/48dp sizes and missing loading-state semantics. This was an executed
  failure, not an intentional compile error.
- First implementation test compile stopped on a missing testTag import; kept
  in `shared-action-first.log`, then corrected.
- The next run had 42 tests / 4 failures: 3 centered short-label line-bound failures
  and 1 focus request rejected in the host's initial touch mode. All 12 large-text,
  semantics/callback and icon-containment cases passed. The label layout changed;
  the keyboard test now explicitly requests keyboard input mode and retains a
  real focus request plus before/after pixel assertion. No injected focus
  interaction or ignored failing assertion is used to manufacture acceptance.
- The next run had 34 tests / 1 failure: the final payout Row action was squeezed
  out. After the wrapping/scrolling correction, the combined selectors passed
  90 tests / 9 suites with zero failures, errors or skips. The final full run
  also includes stronger viewport bounds and each caller's actual action kinds.
- Final full verification: **3,155 tests / 359 suites, zero failures/errors/skips**;
  lint zero errors, 82 warnings and two hints; debug and unsigned R8 release
  successful in 6m 24s. All 791 captured source hashes match the committed source.
  A new test-helper naming warning found in the first full run was corrected and
  the full command rerun; no lint rule or test failure was suppressed.
- Independent scoped critic **9.595/10**, QA **9.58/10**. These accept this local
  foundation/action slice; no full-app score, whole-page/device/TalkBack acceptance
  or shipped release is claimed.

## Boundaries

Colors and geometry do not authorize an action. These controls preserve callers'
`enabled`/`disabled` and callback inputs; they do not add asynchronous submission
ownership or replace server-side permission checks. Existing A3/A4/A12 and release
blockers remain open.

Default Material widgets keep their own disabled-state policy; the explicit
readable disabled pair is established for these two shared buttons. Their local
gate is not a claim that every old Material button/field, legacy hardcoded
surface or every screen already meets the new component contract.

The font provenance fix also preserves all upstream notice bytes through Git's
Windows checkout filters. A path-scoped whitespace attribute records Space
Grotesk's original CRLF and one trailing space; app-source whitespace checks
remain unchanged. Raw/index/filter hashes and the original diagnostic are in
[font-provenance-check.json](../evidence/ui-foundation/font-provenance-check.json).
