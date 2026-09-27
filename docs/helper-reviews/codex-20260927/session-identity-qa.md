# Session identity integration — independent QA, 27 September 2026

**Provisional HOLD, 8.8/10 for the combined auth/root milestone.** Reviewed
code checkpoint `e462bf1dd0682352ae08b145cb51d90e10161156` against accepted
main `11ac01c1d9e55439eb0673036e5589a07677e629`. The branch selectively
ports the session/root/navigation change and its three new test classes;
accepted Welcome, SignIn, SignUp footer and A3 deep-link source/tests remain
in place. The new English-only `auth_session_verify_error` is marked
`translatable="false"`, matching the existing `StringsParityTest` contract.
The coordinator reports targeted identity/root/handoff/parity checks **35/0**
on this combined tree. A full unit/lint/debug/unsigned-release run is still
in progress; no full-green, hosted-CI or device claim follows from 35/0.

The synthetic tests meaningfully cover observed A→signed-out→A, direct A→B
and observed A→B→A; late noncooperative profile responses; blank IDs,
Unknown, duplicate/email-only events and manual refresh; old-host disposal,
back-stack reset, covered pointer input, wrong-role Main admission and a
failed-profile Retry. Source keeps the auth collector off network I/O and
uses generation/request checks before publishing the root profile. This is
useful bounded evidence for **observed** identity boundaries, not proof of
repository-level session incarnation or all account-owned mutations.

## Mandatory gaps before combined auth acceptance

1. **HIGH — signed-in `NeedsRole` dead end.** `SessionViewModel` produces
   `NeedsRole` for an unconfirmed/unsupported server role, while
   `AppNavGraph` sends it to `AUTH_GRAPH`; that graph has no role-recovery
   route or signed-in exit. Tests assert that Main stays closed but do not
   prove the user can recover. Add composed cold-start and failed-`addRole`
   cases through owner-bound retry/role selection/sign-out and a successful
   server-confirmed return.
2. **HIGH — in-flight cleanup can cross accounts.** The old login can enter
   `SignOutCleanup.wipeLocalUserState()` after an owner check, then B can
   replace it while that global operation is suspended. The current tests
   reject a late A result before cleanup begins; they do not block midway
   through real cleanup and prove B's outbox, preferences and token survive.
   Add a noncooperative cleanup barrier and B sentinel-state assertions;
   fence actual mutation owners in A4/S1 before broad security acceptance.
3. **HIGH — signup writes use the live session.** SignUp's footer remains
   clickable during submission. `SignUpViewModel` holds the selected role
   but no signup-account/session ticket; after a late A response it invokes
   `ProfileRepository.addRole`, which acts under whichever account is now
   signed in, then writes global role preferences and emits a route effect.
   Add deferred A-signup→B-login→late-A and A→out→A tests asserting no B
   RPC/prefs/analytics/effect. A client ID-only check cannot prove a new
   same-account login incarnation or protect a request already in flight.
4. **HIGH — phone obligation depends on the current route.**
   `authHandoffDestination` blocks hospital signup handoff while the nested
   route is `AUTH_SIGN_UP`/unfinished phone, but if footer or Back moves to
   `AUTH_SIGN_IN` before a late hospital profile validates, the policy can
   select Main/ordinary Onboarding without the dedicated signup phone route.
   Its three pure tests cover each route separately, not that transition.
   Add a composed deferred-signup→footer/Back→late-confirmation case and
   bind the phone obligation to the signup attempt/owner rather than a route
   string alone.

Further limits: `RootSessionBoundary` hides a retained host during Unknown
or revalidation but does not stop every background screen effect; SDK
identity transitions entirely conflated upstream remain invisible. The
Retry cover has no sign-out escape, 48dp/200%-text/dark-render and physical
TalkBack proof. The pure phone policy test is not a composed phone-save,
profile-refresh and process-restart journey. These are separate from the
passing observed-boundary tests. Keep this candidate WIP even if the full
Gradle bar turns green; independent security review and applicable hosted CI
remain required after mandatory defects are fixed.
