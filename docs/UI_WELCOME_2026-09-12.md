# Welcome UI and accessibility slice

Base: `e58c48c2774a77aa0e725f1945da4e48a0fd5873`.
Original helper branch: `codex/ui-welcome-20260912`.
Original helper worktree: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-ui-welcome-20260912`.
Integrated and verified by the coordinator in `codex/auth-integration-20260911`.

Scope is the signed-out Welcome screen only: AX-01/02 from
`GPT53_ACCESSIBILITY_INVENTORY.md`, aligned with the renewal plan and the
reviewed login journey. The public callbacks, legal destinations, authentication,
role policy, shared components and dependencies remain unchanged. Role descriptions
are information, not selectable cards before authentication.

Frozen acceptance checks before implementation:

- Named Sign in, Create account, Terms of service and Privacy policy buttons;
  each invokes only its supplied callback once. Brand heading, decorative logo,
  and no role selection or extra click targets.
- Every word and complete action reachable at 320dp / 2x font in EN/HI/TE, plus
  640dp x 320dp short landscape / 2x font in each language. No ellipsis, clipped
  lines, overlapping targets, or fixed-height text-bearing actions. CTA target
  minimum 52dp with padding around text; legal targets minimum 48dp.
- Explicit colors and actual native-Canvas foreground/background evidence in
  both themes, at least 4.5:1 contrast for every rendered text item. Keep Seva
  forest green and the existing logo; no payment or success guarantees.
- Independent coordinator-owned critic and QA review, with the renewal plan's
  minimum scores and hard blockers. This slice is not whole-auth acceptance.

The first checkpoint (`8e94a3d9`, followed by a test-only DpRect API correction
at `86845687`) contains a callback-only `WelcomeContent` extraction and a new
11-test `WelcomeScreenUiTest` using the existing isolated manifest-free,
native-Canvas Robolectric harness. Layout/styles/copy were unchanged for the
coordinator's red run:

```text
./gradlew.bat :app:testDebugUnitTest --tests "com.equipseva.app.features.auth.WelcomeScreenUiTest"
```

The coordinator recorded an initial test compile failure (`DpRect.height` is
unavailable in this Compose version), preserved that log, and corrected the
test to subtract rectangle edges without changing its padding requirement.
The next run compiled and produced **11 tests, 11 failures** on the unchanged
UI: missing scrolling, separate legal actions, heading and the required
informative/localized content. Evidence is in the coordinator's
`work/verification/auth-integration-20260912/ui-expanded-red-xml/` and
`ui-expanded-red2.log`; the compile failure is `ui-expanded-red.log`.

Implementation followed that runtime red result. Welcome now has one scrolling,
width-bounded content area; a decorative logo and named brand heading; plain
hospital/engineer descriptions; flexible 52dp-minimum CTAs; and separate
48dp-minimum legal buttons. The brand header stacks at large font scales rather
than reducing the user's text size. Copy removes the old on-time payment
guarantee. All ten `welcome_*` strings are present in EN/HI/TE, and the existing
legal URLs and public callbacks are preserved.

At its original delivery the helper had not run Gradle or pushed, and explicitly
left implementation unverified. The coordinator then integrated helper content
`456c051cb4fd5769a5ec8e57ec2f2f8bf316a9ae` and completed the following checks.

## Coordinator verification, 12 September

The first new-UI run passed five tests and failed six aggregate overflow checks.
Recorded dimensions proved the brand fit its actual measured box: 171px measured,
272px paragraph allocation, 170.5px intrinsic width and 169.81888px line end.
The oracle now checks actual measured line and viewport bounds, retaining its
1px tolerance, full characters, no ellipsis and height constraints. This stricter
oracle exposed centered action allocation mismatch; both centered Text elements
now fill the available interior width. Fonts and action padding were preserved.
All original failures and the one-case diagnostic remain in the evidence archive.

Final focused Welcome: **11 tests, zero failures/errors/skips**. Full candidate:
**3,110 tests / 355 suites, zero failures/errors/skips**, lint with zero errors,
82 warnings and two hints, debug and unsigned R8 release assembly. The first full
command failed starting Bash for its unchanged release precheck; recovery added
installed Git Bash to the process PATH and reused successful same-source checks.
No app/test/build source changed across all 768 frozen source/config files.
`apksigner` confirms the release artifact is unsigned; no signed release is claimed.

Final source hashes, command outcomes and independent critic/QA dispositions are
in [verification.json](evidence/auth-integration/verification.json),
[critic-review.md](evidence/auth-integration/critic-review.md) and
[qa-review.md](evidence/auth-integration/qa-review.md). See the
[render evidence](evidence/welcome-ui/README.md) for the actual screenshots.
Both themes meet 4.5:1 for all eleven text items, with a measured minimum 8.3127:1.

These synthetic tests do not launch real accounts, authentication repositories,
browser or network. Native-Canvas renders are simulated UI evidence. Device,
keyboard/TalkBack ordering and Hindi/Telugu native-speaker review remain separate
open evidence; no such acceptance is claimed here.
