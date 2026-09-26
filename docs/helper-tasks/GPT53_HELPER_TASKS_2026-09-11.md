# Paste into GPT-5.3-Codex

Help continue EquipSeva Android with focused, test-first coding. The coordinator
owns A2 root routing, session presentation, role-picker UI and their tests.
Do not touch those files or repeat the completed A1/Room v5 work.

Repository: https://github.com/ganeshnaik166/equipseva-android.git

Create a NEW isolated checkout/worktree and branch
`codex/helper-engineer-status-20260911` from the fetched
`origin/codex/security-foundation-20260907`. Record the exact base SHA. Use the
September 11 A2 WIP save checkpoint or newer, not the earlier `64107db7` snapshot.
The coordinator still owns A2, including its remaining dark-theme contrast fix.
Never switch/reset/clean the coordinator's checkout. Keep any existing changes.

Read docs/HANDOFF_2026-09-10_END_OF_DAY.md,
docs/HANDOFF_CLAUDEDEV_AUTH_AUDIT.md (sections 8–9 and A10), and
docs/RENEWAL_EXECUTION_PLAN.md. Read newer docs/HANDOFF_AUTH_A2.md if fetched.
Treat old implementation proposals as hypotheses to validate against source.

Complete these small milestones sequentially:

1. **A10 engineer verification-state isolation.** Own only DeepLinkHost.kt's
   engineerStatus initialization/refresh logic and a NEW focused
   DeepLinkHostEngineerStatusTest.kt. Write failing tests first for signed-out
   reset, same-account sign-out/sign-in refetch, direct A→B replacement, observed
   A→B→A, late noncooperative responses, duplicate/emails-only session events,
   blank IDs, Unknown and failed/manual refresh. Replace the filtered/distinct
   observer with owned state/request handling. Never suspend the full auth
   collector on network I/O; prevent a late result from publishing into the next
   login, and do not queue a manual refresh waiting for a future account. Record
   the chosen Unknown behavior explicitly. Prove valid fresh requests still work.
   Do not edit DeepLinkRouter, event-channel delivery, lastScreen handling,
   SessionViewModel, AppNavGraph, MainNavGraph, RoleSelect or auth repositories.
   Repository-level unobserved identity boundaries remain an explicit limitation.

2. **Notification parser regression coverage, tests only.** In a NEW uniquely
   named NotificationDeepLinkEdgeCasesTest.kt, exercise the existing pure mapper's
   legitimate job/chat/engineer/notification cases, missing fields, unknown kinds,
   malformed/encoded IDs and boundary strings. Read the actual contract first.
   Keep current-behavior characterization distinct from desired security targets.
   Do not bless an insecure route, invent a route policy, alter shared tests or
   change parser production code; report reproducible defects to the coordinator
   for A3. Keep any reproduced failing target test in a clearly labeled WIP
   commit with its exact command/result; do not call that milestone green.
   Never delete, ignore or relabel failing tests to manufacture acceptance.

3. **Bounded accessibility inventory, report only.** Inspect Welcome, SignIn,
   SignUp and Profile for fixed-height text, tiny action targets, missing labels,
   misleading error/retry copy and unpaired foreground/background colors. List
   exact file/line evidence and a proposed minimal test/fix per issue. Exclude
   current A2 RoleSelect/recovery files. Do not redesign those screens yet.

Use existing Kotlin/coroutine/MockK/Robolectric tooling. Tests must be synthetic,
offline and cancellation-aware; preserve the production API contract. Do not
add dependencies, suppress failures, change security gates or run real accounts.
If Gradle is unavailable, say unverified; never invent a green run. On this laptop
read C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-build-slot.md
before Gradle. While BUSY, continue source/test/report work without launching a
competing Gradle process. Recheck the slot before starting a build; preserve
another session's reservation. Do not request model-setting confirmation.

After milestone 1, run its targeted tests and applicable full unit/lint/debug/
release checks before calling it accepted. Record signing/configuration limits;
an unsigned release assembly is not a shipped release. Keep each milestone in a
separate commit. Save a concise docs/HANDOFF_GPT53_HELPER.md with exact base/head
SHA, changed files, tests/counts/failures, remaining risks and merge points. Fetch
before pushing; push only your own branch, never force-push or merge main. The
coordinator handles integration and independent critic/QA acceptance.
