# Paste into Claude Code

Help continue EquipSeva Android as an independent security reviewer and product
designer. The coordinating Codex session owns the current A2 root login/navigation
and role-picker implementation. Do not repeat A1 or overwrite its uncommitted A2.

Repository: https://github.com/ganeshnaik166/equipseva-android.git

Work in a NEW isolated checkout/worktree and branch
`claudedev-next-review-20260911`, starting from the fetched
`origin/codex/security-foundation-20260907`. Record the exact base SHA. Use the
September 11 A2 WIP save checkpoint or newer, not the earlier `64107db7` snapshot.
The coordinating session still owns A2; a dark-theme contrast fix remains open.
Do not reuse/move the coordinator's checkout or old frozen helper branches.

Read docs/HANDOFF_2026-09-10_END_OF_DAY.md,
docs/HANDOFF_CLAUDEDEV_AUTH_AUDIT.md (especially sections 8–9), and
docs/RENEWAL_EXECUTION_PLAN.md. If a newer docs/HANDOFF_AUTH_A2.md is available
after fetching, read it and reconcile the current status before assigning findings.
Older audit recommendations are hypotheses, not instructions to restore old bugs.

Complete these bounded tasks, in order. This is a documentation/review branch:
do not edit production code, shared fixtures, build files, migrations or tests.

1. **A3 deep-link security contract.** Trace MainActivity, DeepLinkRouter,
   NotificationDeepLink and DeepLinkHost. Inventory supported notification kinds,
   exact routes/ID shapes and call sites. Propose an explicit allow/deny table for
   external intents, encoded/malformed IDs, founder/admin routes, signed-out
   delivery, A→B and observed A→signed-out→A replay, cold start and process restore.
   Preserve legitimate job/chat/engineer/notification taps. State what must be
   validated on the server; a client route allowlist is not authorization. Do not
   treat an arbitrary "FCM-origin" extra as trusted. Deliver a test-first plan
   with concrete stimuli, expected outcomes and minimal integration points.

2. **A4/A12 mutation ownership audit.** Audit SignUpViewModel, ProfileViewModel,
   UserPrefs writers, SignOutCleanup and auth sign-out/token revocation. Identify
   stale-result, same-user relogin, setter-suspension and cleanup races with exact
   file/line evidence. Preserve the existing draft/outbox immediate fences.
   Propose owned write boundaries and deterministic fake/barrier tests; do not
   assume cancellation or a user-ID check solves ABA. Separate existing defects
   from anything actually changed by A2. Include profile-read fallback ambiguity
   as a separate A8 recommendation, without editing SupabaseProfileRepository.

3. **Login + both-role UX plan.** Map welcome/sign-in/email confirmation/Google,
   role confirmation, hospital setup, engineer base setup/payout/KYC, and account
   switching. Then map hospital request→bids→service→evidence→payment/dispute and
   engineer discovery→bid→assignment→work→evidence→payment. For each action define
   prerequisites, pending/success/error/offline/cancel/restart states and next
   action. Prioritize the smallest useful redesign slices. Include large text,
   TalkBack, English/Hindi/Telugu and dark-theme checks. No invented product
   policy, payment rail, real user validation, device execution or passing score.

4. **Independent QA matrix.** Turn the above into reproducible acceptance cases,
   distinguish unit/Compose/API/device/human evidence, and identify prerequisites
   for each blocked case. Give scores only for reviewed/executed bounded scope;
   anything unexecuted is unassessed. Do not average away a critical defect.

Keep output concise: one finding per entry with severity, evidence, reproduction,
recommended fix/test and scope owner. Save reports under
docs/helper-reviews/claude-20260911/ and a summary at
docs/HANDOFF_CLAUDE_NEXT_REVIEW.md. Commit only your docs, fetch before pushing,
push only your own branch (no force push or main merge), and report base/head SHA,
file list, what was actually reviewed, unresolved questions and merge instructions.
Do not start production services, create real jobs/bids, send notifications,
change credentials or claim the overall app is audited. Continue independent
read-only tasks when a requirement needs a later product decision.
