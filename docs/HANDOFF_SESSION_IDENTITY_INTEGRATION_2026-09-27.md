# Session identity port onto accepted main — WIP handoff

Branch `codex/session-identity-integration-20260927` in the isolated worktree `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-session-identity-integration-20260927`. Freshly fetched base `origin/main` was `11ac01c1d9e55439eb0673036e5589a07677e629`, which contains accepted A3-01, Welcome accessibility, SignIn recovery, SignUp navigation and footer. Scope declaration `9bc279d0`; source/test checkpoint `8b29e781`. The original WIP source is `8e52900994b2c4304627385cbb0c1815a2f2babf` with its [historical handoff](HANDOFF_SESSION_IDENTITY_2026-09-26.md) at `b3b7bc45`; that checkout was not changed.

## Port and conflict resolution

- Ported `SessionViewModel.kt`, `SignUpScreen.kt`, `AppNavGraph.kt`, `AuthNavGraph.kt`, `MainNavGraph.kt`, new `RootSessionBoundary.kt`, and three focused tests (`SessionIdentityBoundaryTest`, `AuthHandoffPolicyTest`, `RootSessionBoundaryTest`). All nine Kotlin file hashes match the original WIP source commit exactly. Source behavior and its known risks are described in the historical handoff.
- Main and WIP overlapped in `SignUpScreen.kt` and `strings.xml`. Main's SignUp accessible-footer blob was already the WIP's pre-callback base; the only Kotlin delta adds the engineer `NavigateToHome` root-refresh callback and forwards that effect. Main's five newer Welcome strings were retained; only `auth_session_verify_error` was added, with `translatable="false"` under the owner's English-only policy. No accepted Welcome, SignIn or deep-link source was replaced. There were no textual merge conflicts because the port was file-selective.
- Static checks: `git diff --cached --check` passed before the code commit; all nine source/test hashes were compared against `8e529009` and matched. No Gradle, test, lint, assembly, device, visual or hosted CI result exists yet for this combined branch.

## Verification boundary

The old WIP, on the older `edae85ed` base, passed four focused classes **34/0**. Its first full command failed **2,941 tests / 1 failure** at `StringsParityTest` because the error string lacked `translatable="false"`; lint and release assembly did not finish. These counts cannot be applied to the new main integration. The shared Gradle slot was BUSY with root's Welcome full run during this port. Once root explicitly hands back a FREE slot and all prior Gradle processes exit, reserve it, run targeted identity/root/navigation plus `StringsParityTest`, then the full unit/lint/debug/unsigned release sequence if targeted is green. Preserve exact-head logs and report failures without hiding them.

Independent security critic and QA must review the frozen integrated diff and evidence separately at **at least 9.5/10**, with no mandatory blocker, before any scoped acceptance. Applicable hosted Android CI and device/TalkBack checks remain additional gates. Do not merge this WIP to main or deploy it from this checkpoint.

## Open risks and next work

`NeedsRole` still lacks a complete recovery/role picker; signup's failed `addRole` can leave a user stranded and its mutation is not owner-fenced across an account switch. Other cleanup/global writers, SDK login identity, buffered deep-link replay, hidden-host background effects, and the signup-during-submit race remain outside this port. Even green compilation would not resolve these security limits. Keep the old WIP and all parallel worktrees intact; no main or production action is authorised by this handoff.
