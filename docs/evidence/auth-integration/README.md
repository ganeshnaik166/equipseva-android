# A2 / A10 local integration evidence

The governing scope is [AUTH_INTEGRATION_2026-09-11.md](../../AUTH_INTEGRATION_2026-09-11.md).
Welcome is a separate component slice under [UI_WELCOME_2026-09-12.md](../../UI_WELCOME_2026-09-12.md).
Use `verification.json` for executed commands, per-suite totals, failed cases,
768 final source/configuration hashes, artifact hashes and environment limits.
Independent dispositions live in `critic-review.md` and `qa-review.md`.

The final full unit run has 3,110 tests across 355 suites with zero failures,
errors or skips. Lint reports zero errors, 82 warnings and two hints. The
release result must be read separately in the manifest: a successful unsigned
R8 assembly does not satisfy production signing or the whole-app release gate.

## Preserved failure history

- Initial A2/A10 red: 63 tests, 15 failures. Dark button contrast and current-auth
  admission/publication plus fetched-row ownership were real component defects.
- Focused green: 189 tests. Two wrong package selectors omitted ten carried
  role/recovery cases; later targeted and full bars execute both actual suites.
- Intermediate full: 3,097 passing tests, but the command failed lint on an
  unescaped Windows SDK drive colon. Only ignored local SDK configuration changed.
- Expanded UI first failed to compile because `DpRect.height` is unavailable;
  the test now subtracts its edges. Runtime red then reproduced 11 Welcome and
  two radio failures. Role radio contrast is now measured in its own drawn region.
- Welcome's first implementation passed five tests and failed six layout cases.
  A diagnostic preserved the brand's measured width 171px, paragraph allocation
  272px, intrinsic width 170.5px and line end 169.81888px. The aggregate overflow
  flag did not describe glyph clipping. The corrected oracle checks line edges
  against actual measured width, semantic viewport bounds, complete characters,
  height constraints and absence of ellipsis, retaining the original 1px tolerance.
- That stricter oracle exposed mismatched centered-action coordinates: six
  failures were retained. Production action and legal text now fill their
  available interior width; fonts and target padding were preserved. All 11
  Welcome cases subsequently passed.
- The first final combined command passed all 3,110 tests and lint but failed
  starting `bash` for the unchanged release precheck. Installed Git Bash was
  added to the process PATH for recovery; no task or security guard was excluded.
- Strict `PRECHECK_LOOSE=0` release deliberately refuses the missing keystore.
  The documented CI mode `PRECHECK_LOOSE=1` is compile/shrink evidence only.

Raw logs, complete XML and every render remain in the sibling local directory
`work/verification/auth-integration-20260912`. Final capture directories were
created afresh after archiving earlier cumulative measurements. No historical
failed cases, screenshots or logs were deleted to obtain acceptance.

## Scope limits

The role images and [Welcome viewports](../welcome-ui/) are synthetic,
manifest-free Robolectric native-Canvas renders. Each large-text action is
scrolled to and checked separately; an end viewport does not show all actions
at once. `initial-viewport` is a sample, not a claim of scroll-zero launch state.
Real device, TalkBack, keyboard/IME/insets, native-language and representative
user validation remain open.

A10 retires ownership on Unknown and observed login boundaries. Loading, missing
or mismatched rows and failed refreshes remain null; fresh valid requests recover.
An immediately unavailable current-auth probe fails closed and is cancelled.
Entire same-ID login boundaries lost by the repository cannot be identified here.
The existing manual method has no production post-KYC caller; no new wiring is
claimed. A3 route/replay admission, A4/A12 mutation/cleanup/token ownership,
provider/server/Storage/FCM integration, full-app audit and signed release remain
separate open gates. The earlier dispatch commit `e58c48c2` remains an A3 WIP.
