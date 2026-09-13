# UI-02 OTP checkpoint: WIP, not accepted

Saved at the owner's explicit stop request on 13 September 2026. Do not promote
this checkpoint to main or call it green. No Gradle process was launched after
the stop. The current tree has edits newer than the latest test result.

The [checkpoint ledger](checkpoint.json) contains exact baseline/source hashes,
test counts, failures, logs/XML and render hashes. All fixtures are synthetic.
The original pre-policy test and executed review tests are preserved under
`snapshots/`; they are historical evidence, not additional compiled test suites.
The local attributes preserve captured bytes, including reporter whitespace and
line endings, so Git stores the exact evidence hashes. Run logs/XML are treated
as captured artifacts; readable failure summaries remain in the JSON ledger.

| Executed phase | Tests | Failures | Meaning |
| --- | ---: | ---: | --- |
| red-ui | 12 | 6 | Baseline field and pending-copy targets |
| red-vm | 13 | 4 | Baseline duplicate/busy admission targets |
| target-1 | 42 | 1 | Verifying sheet visually hidden by native Back |
| red-review | 33 | 5 | Back, UI retained submit during send, two VM send/verify overlap cases, wrapped send cancellation |

All runs had zero errors/skips. They used the local existing Gradle, Kotlin,
coroutine, MockK and Robolectric tooling. No dependencies, accounts or production
services were added. These are focused runs, not the full verification bar.

After red-review, root added `ModalBottomSheetProperties` disabling the library's
Back handler and a dialog-scoped `BackHandler`, blocked button/IME submission while
sending, and asserted native dispatcher ownership. Those changes are uncompiled
and unrun. The critic strengthened the gallery's outline measurement, entire
clickable-control containment and actual host secure flags, also unrun.

The VM still lacks its sending guard in `submitEmailOtp` and the active-coroutine
checks before result publication. Five further cancellation cases were saved
without execution. Current test-source inventory: 23 VM tests, 15 new UI
contracts, 8 new gallery tests, and 5 unchanged OTP smokes (51 total by source
inventory; **not a passing test count**). Physical scrim/drag and API34 predictive
Back tests remain to be authored/integrated. No critic or QA rating was awarded.

The selected PNGs and measurements come from target-1's synthetic native windows,
including actual platform font scale 2.0, light/dark and English/Hindi/Telugu.
They predate the new unrun geometry assertions. They are not device, TalkBack,
native-language or release evidence.

Raw local evidence remains in `work/verification/ui-otp-20260913`. Complete prior
accepted input evidence is separate at `docs/evidence/ui-inputs`; its 3,198-test
green bar cannot be applied to this checkpoint. Full unit/lint/debug/release,
independent acceptance, A3/A4/A12/account/provider, dependency and signed-release
gates remain open. Website/dashboard updates remain stopped.
