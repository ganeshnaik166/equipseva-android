# Contributing to EquipSeva Android

This doc captures the conventions that the v1-launch branch baked in. New code is expected to follow them; reviewers should call out drift.

## Architecture rules

1. **`features/*` may depend on `core/*` and `designsystem/*` — never on each other.** Cross-feature flows go through the nav graph (`navigation/Routes.kt` + `MainNavGraph.kt`). A repair → chat handoff goes via a route + `DeepLinkRouter.Event`, not a direct import.
2. **No Java.** Kotlin 2.x throughout. Compose for UI, coroutines + Flow for async, Hilt + KSP for DI.
3. **Hilt-injected repositories own all Supabase / network calls.** Compose / ViewModels do not import `supabase-kt` directly.
4. **`StateFlow` for UI state, `SharedFlow(replay = 0)` for effects.** Channels are reserved for outbox / typing indicators where backpressure matters. (See `SignInViewModel._effects` comment for the PR #584 background.)

## The test-pinning convention

The bulk of the repo's testing investment lives in **pure-Kotlin / Robolectric-free** helper tests. The rule is:

> Any non-trivial gate, formatter, classifier, or copy assembler gets lifted into a top-level `internal fun` and pinned by a JUnit test that exercises the regression target.

This means:

- **Lift inline `@Composable` privates into top-level `internal fun`** as soon as the logic is more than rendering. The Compose function stays a thin wrapper that calls the pure helper. Example: [`canConfirmDeleteAccount`](app/src/main/kotlin/com/equipseva/app/designsystem/components/DeleteAccountSheet.kt) and the matching [`CanConfirmDeleteAccountTest`](app/src/test/kotlin/com/equipseva/app/designsystem/components/CanConfirmDeleteAccountTest.kt).
- **Lift inline `if (queuedUid != null && queuedUid != currentUid)` guards out of suspend ViewModels / handlers** into pure helpers with explicit policy names. Example: the 4 outbox handler cross-user gates — [`notificationReadOwnerGateReason`](app/src/main/kotlin/com/equipseva/app/core/data/notifications/NotificationReadOutboxHandler.kt), [`chatMessageSenderMismatchReason`](app/src/main/kotlin/com/equipseva/app/core/data/chat/ChatMessageOutboxHandler.kt), [`repairBidEngineerGateReason`](app/src/main/kotlin/com/equipseva/app/core/data/repair/RepairBidOutboxHandler.kt), [`jobStatusActorGateReason`](app/src/main/kotlin/com/equipseva/app/core/data/repair/JobStatusOutboxHandler.kt).
- **Pin the why, not just the what.** A test like `assertEquals("Resolved: 23 May 2026 14:30", ...)` is fine; a test with a KDoc comment explaining *why a trailing dot would be wrong* is better and survives a refactor that has the same intent but different output.

### What's worth pinning

| Category | Example | Pinned because |
|---|---|---|
| Server CHECK mirror | `bidComposerAmountValid("0")` → false | Server rejects with `amount_must_be_positive`; client gate prevents the bad request and the confusing error |
| Trust-and-Safety gate | `canSendChatMessage(counterpartBlocked = true)` → false | Block-list integrity — a refactor that flipped the predicate would silently route messages to blocked peers |
| Locale stability | `inlineStarsRatingLabel(4.5)` uses `Locale.US` | Turkish-locale i-casing + Hindi/German comma-decimal bugs |
| Unicode glyph | `resolvedDisputeResolvedLine` uses U+00B7 middle-dot | Designer-pinned glyph; a copy-paste swap to a regular dot or comma would break visual parity |
| Cross-surface invariant | 7-day AMC expiry → Danger pill (INCLUSIVE) | Pinned identically on hospital + founder sides; if one drifts the displays diverge |
| Role-aware copy | "Released to you" (engineer) vs "Released to engineer" (hospital) | Wrong pronoun on the wrong side leaks the counterpart's perspective |
| Wire-frozen literal | `relatedEntityType = "repair_job"` | De-dupe RPC matches on this string |
| Razorpay vocabulary | Halted / Cancelled / Completed / Expired | Must match user's bank statement copy |

### Test naming

- One test method per behaviour: `\`zero amount invalid (server CHECK enforces positive)\``.
- Avoid backtick-illegal chars in names: `>`, `<`, `..`, parens-with-periods are silent compile failures on Kotlin test method names. Use words instead.

### Outbox handler asymmetry — DO NOT UNIFY

The four outbox handler cross-user gates have **intentionally asymmetric** policies. Each is pinned in its own pure helper + test so a refactor that unified them would fail loudly:

- `chatMessageSenderMismatchReason` — STRICT. Payload schema enforces non-null sender.
- `notificationReadOwnerGateReason` — LENIENT. Null queued owner falls through to RLS.
- `repairBidEngineerGateReason` — LENIENT. Null queued engineer falls through to RLS.
- `jobStatusActorGateReason` — STRICT. Null queued actor drops with refusal copy.

The strict / lenient split exists because job-status flips have escrow + AMC ledger + reviews side effects, so a "different user finishes the old user's job" path is a T&S landmine.

## Code style

- **No comments that just describe what the code does.** Comments explain *why* — a hidden constraint, a past incident the code is guarding against, a subtle invariant. Identifiers should already say what.
- **Never reference the current task / PR / fix in code comments.** Things like "added for feature X" or "fixes #234" rot — those belong in PR descriptions and git commit messages. Comments should make sense to a developer 18 months from now with no PR context.
- **`internal fun` over `private fun` when there's any chance the helper is worth testing later.** Internal is package-visible to tests; private isn't.
- **Modifier first optional** on Compose composables (lint `ModifierParameter`). The whole designsystem has been refactored to this; new components must follow.
- **No `@VisibleForTesting`** — keep helpers `internal` instead. Adds nothing the package-internal visibility doesn't already provide.

## Commit / PR conventions

- Conventional commit prefixes: `test:` (new test/helper-pin), `fix:`, `feat:`, `chore:`, `refactor:`, `docs:`, `ci:`.
- Commit messages explain *why* in the body, not just the file list — git diff covers what changed.
- Each commit should leave the tree green (tests + lint). The CI gate runs both on every PR; a red CI blocks merge.
- PRs are usually stacked. The convention: a PR named `r1`, `r2`, `r3` (round 1/2/3 of an effort) is the chain marker; each builds on the prior.
- The current launch branch (`test/more-validators-helpers-r3` → PR #933) carries ~220 stacked test-pin commits. Reviewers can read the commit log linearly; each commit is small enough to inspect.

## Verification before pushing

```bash
./gradlew :app:testDebugUnitTest    # 2,400+ tests
./gradlew :app:lintDebug            # 0 errors gate
./gradlew :app:assembleRelease      # R8 shrink + obfuscate must succeed
```

CI runs the same three on every PR (see [.github/workflows/android.yml](.github/workflows/android.yml)). Don't push if any of the three failed locally — CI rejecting your PR after merge is more expensive than the 90-second re-run.

## Deferred items

Tracked by Dependabot (weekly grouped minor/patch sweeps in [.github/dependabot.yml](.github/dependabot.yml)):

- 105 GradleDependency minor/patch bumps.
- GitHub Actions version updates.

Held back for coordinated upgrades (NOT in Dependabot scope — open a tracked spike instead):

- AGP + KSP major upgrades (touch ProGuard rules, Hilt KSP processor, Compose compiler).
- `googleid` 1.1.1 → newer (changes credential-type constant; needs auth-flow regression test).
- `targetSdk = 35` → 36 once Android 16 stable.
