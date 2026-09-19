# Independent S2 / S3 review — 2026-09-19

Read-only critic/security review of the uncommitted candidate over `69034d84933c961e6f20c504da6f81158b9aed36`, in `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-quality-integration-20260919`. No Gradle, production queries, commits, or source edits by this reviewer. Scores below are reviewer judgment about the named implementation and test design only, not app/security/release acceptance.

## Disposition and scores

- **S2 local installation-token cache fix: 9.5/10, no new blocker found within that narrow scope.** Removing the post-network `dao.clear()` structurally prevents an old revoke from deleting any replacement local row, including when the physical token is unchanged. Its five synthetic real-SDK/HTTP tests cover success, failure, replacement same/different token, captured remote filters and signed-out admission. This is not proof of successful remote revocation or complete push isolation.
- **S3 login-envelope routing: 9.2/10, recovery disposition needed before 9.5.** The generation envelopes, delivery-time checks, initial/later Unknown separation and fresh-link positive controls address the original buffer replay defects. A same-login recovery path after explicit clear has no rearm mechanism. No new cross-account navigation bypass was found in the reviewed synchronous Main delivery chain; the concrete recovery gap is described below.

## S3-R1 — P2: failed/cancelled logout can leave a recovered same-A session unable to open fresh links

Evidence:

- `app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkRouter.kt:169-176` records the current A as `clearedUserId` and retires buffers. Lines 200-202 reject every later SignedIn(A) while that latch is present; lines 183/189/196/204 clear it only after an observed boundary/different account.
- `app/src/main/kotlin/com/equipseva/app/core/auth/SignOutCleanup.kt:86` calls this clear before later suspendable work and before auth sign-out.
- `app/src/main/kotlin/com/equipseva/app/features/auth/SessionViewModel.kt:292-303` supports a failed/cancelled sign-out while A remains current by releasing revocation/progress into retryable recovery. `refreshNow()` at 226-232 can then load a valid profile and restore Ready(A) without an auth transition. There is no router recovery notification.
- `app/src/test/kotlin/com/equipseva/app/features/auth/SessionViewModelIdentityTest.kt:1015-1028` already models a dependency cancellation retaining A, but tests another logout attempt only. The new routing test `DeepLinkDeliveryOwnershipEdgesTest.kt:101-121` correctly demands the fence remain in place during logout, but rearms it only through SignedOut -> A.

Deterministic regression to add at the integration boundary: instantiate the real router/host alongside the existing SessionViewModel fixture; buffer an old A route; have cleanup call real `router.clear()`; return a cancellation from the sign-out dependency while auth remains A; assert retryable recovery, then `refreshNow()` and successful profile bootstrap back to Ready(A). Dispatch a newly received A route. The old route must remain rejected, but the new route should navigate exactly once. Current routing still drops the fresh route because `clearedUserId == A`.

Ordinary GLOBAL network failure alone is **not** this reproduction: `SupabaseAuthRepository.kt:254-261` falls back to LOCAL sign-out, which normally emits SignedOut and releases the latch. The gap requires cancellation before local sign-out or local-clear failure, both distinct from a normal offline logout. No device/integration execution of this additional scenario occurred here. The S3 author independently confirmed the missing rearm caller and escalated the same edge to the coordinator.

Minimal safe disposition: either keep an aborted logout gated until an actual fresh auth boundary, or notify the router after explicitly owned same-login recovery and issue a new generation. Do not restore the previous generation or merely drop the delivery checks; old host-buffered taps must remain invalid. An explicit recovery API must itself be owner/generation guarded.

## What S3 source and tests do cover well

- `DeepLinkRouter.kt:79-85` carries login generation in internal envelopes without breaking the public event shape. `DeepLinkHost.kt:201-204` preserves it through the second buffer and checks it at final delivery.
- `DeepLinkRouter.kt:145-159,230-257` probes immediate auth for admission and final delivery rather than trusting a lagging secondary state cache. Production `SupabaseAuthRepository.kt:22-42` supplies a mapped replaying SDK StateFlow; the immediate-read assumption matches that implementation.
- Later Unknown, SignedOut and blank IDs retire ownership; the initial Unknown queue alone can hold up to 32 taps in order. A -> B -> A and A -> SignedOut -> A cannot reuse a retired generation when those boundaries are observed.
- Same-ID email-only changes keep the generation. Mismatched recipient IDs still drop, while legitimate fresh matching routes remain deliverable.
- The two new routing classes contain ten cases with fresh positive controls. The existing router owner class has eight and host owner class two. Tests use synthetic auth, no real accounts or network, and cancel host scopes.
- `MainNavGraph.kt:221-232` navigates synchronously in its Main collector, so no new post-check navigation buffer was introduced. Root owner lifecycle remains an additional dependency; the router is not server authorization.

## Existing S2/backend limits — separate from the local cache fix

1. **Versioned revoke contract is unresolved.** This reviewer searched all 3,378 tracked SQL migrations through round3823, including 3819/3821/3822/3823; also searched multiline DELETE/ALL grants, grants on all tables, dynamic format/concatenation grants, and default privileges. `supabase/migrations/20260428320000_security_revoke_delete_grants.sql:29` revokes authenticated/anon DELETE on `public.device_tokens`; no applicable later grant or token registration/revocation RPC was found. `DeviceTokenRegistrar.kt:75-87,116-126` still directly DELETEs through the authenticated client inside swallowed `runCatching`. With that versioned grant state, the register delete fails before its following upsert, and revoke cannot delete. The live database may differ and was not queried. This is a pre-existing contract risk, not introduced by retaining the local token. Verify permissions in a disposable database or authorized read-only schema inspection; do not blindly broaden grants.
2. **Remote same-A login versions remain indistinguishable.** `DeviceTokenRegistrar.kt:122-123` scopes remote DELETE by user and token, not registration version. A request sent for A's old login can match a later A registration with the same token if the server commits it late. The local row now survives, but the HTTP mock does not model server row history or prove protection against that pre-existing remote race.
3. **The documented cross-owner push dedupe was not found in the checked function.** `DeviceTokenRegistrar.kt:72-74` says another owner's rows are deferred to dedupe in send_push. Current `supabase/functions/send_push_notification/index.ts:324-329` fetches that recipient's token rows, and 358-359 sends to each. No cross-owner token dedupe is shown there. Other live triggers/schema may exist; this review does not claim their absence in production.
4. Cancellation swallowing inside refresh/register/revoke and A4 cleanup ownership remain separate boundaries. This patch removes one unsafe local write; it does not establish a complete login-generation token protocol.

## Validation limits and useful next tests

No tests were executed by this reviewer, and no live FCM/Supabase permission or device flow was exercised. Coordinator red/green runs must be recorded independently. Suggested additions after the recovery decision: same-A fresh navigation after aborted logout; S3 mapped-Flow and non-replaying/immediate-probe failure controls; same-A newer local token during delayed revoke as an explicit positive control; disposable server/RLS tests for registration and revocation.

A same-ID auth boundary wholly conflated upstream remains explicitly unobservable. Events beyond bounded buffers may be dropped. Actual RootSessionHost/Activity lifecycle and provider-delivered notifications remain integration/device validation, not implied by JVM success.

Reviewed file SHA-256:

- DeepLinkRouter.kt: `005EF7ABA9848EF7517782FC3157E94469DBBDD165C8CF1FC973AC09E8A97ADC`
- DeepLinkHost.kt: `E47D4DDF8A231662542CEBEFD26A946C639DA631C18A318A070D26C984CA0997`
- DeviceTokenRegistrar.kt: `EA5E513287EE78E881710761C1E86B8E427B6723A83A3FD7242B65565C020DF8`
