# Sync / Security / Build audit — EquipSeva Android snapshot `9a0ecf89`

Read-only audit of `C:/Users/lokes/equipseva-audit-snap` (frozen). Scope: `core/sync/**`, `core/security/**`, `core/observability/**`, `core/util/**`, `core/location/**`, `features/security/**`, Gradle files, `proguard-rules.pro`, `AndroidManifest.xml` (+ referenced XML), `.github/workflows/*.yml`. Adjacent files read only where needed to confirm a finding (feature outbox handlers, `OutboxDao`, `StorageRepository`, `SupabaseModule`, `EncryptedSessionManager`, `DbPassphraseStore`/`AppDatabase`, `SignOutCleanup`, `ChatRepository.sendMessage`). Repository confirmed PUBLIC via unauthenticated GitHub API (`"private": false`). No files modified, no build/DB commands run.

Ordering: severity, then blast radius. 22 findings (no CRITICAL — nothing here is a direct account/money compromise; the HIGHs are silent data loss, duplicated user-visible writes, PII reaching Crashlytics, and a public de-obfuscation map).

---

### SSB-01 [HIGH] Periodic and one-shot outbox workers drain the same rows concurrently — duplicate side effects
- File: app/src/main/kotlin/com/equipseva/app/core/sync/OutboxEnqueuer.kt:54-58; app/src/main/kotlin/com/equipseva/app/core/sync/SyncModule.kt:58-62; app/src/main/kotlin/com/equipseva/app/core/data/dao/OutboxDao.kt:14-15; app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:49-52
- What: The 15-minute periodic work (`outbox-flush`) and the enqueue-triggered one-shot (`outbox-flush-oneshot`) are two distinct unique-work names, so WorkManager runs them in parallel (default executor is multi-threaded; `CoroutineWorker` runs on `Dispatchers.Default`). Both call `nextBatch()`, which has no claim/lease column, so both process the same 25 rows. The chat insert has no client-generated id (`MessageInsertDto` has no `id`), so the same message is inserted twice; both workers also call `markFailed`, burning two attempts per failure.
- Evidence: `enqueueUniqueWork(OutboxWorker.UNIQUE_NAME + "-oneshot", REPLACE, …)` vs `enqueueUniquePeriodicWork(OutboxWorker.UNIQUE_NAME, UPDATE, …)`; `@Query("SELECT * FROM outbox ORDER BY createdAt ASC LIMIT :limit")` — no `WHERE claimed…`; `MessageInsertDto(conversation_id, sender_user_id, message, attachments)` (MessageDto.kt:20-25). The classic trigger is reconnect: constraint-met fires both requests at once.
- Fix: Serialize drains — simplest is a process-wide `Mutex` in a `@Singleton` (`OutboxDrainLock`) injected into the worker and held around the whole `doWork` loop; better, add `claimedAt` to `OutboxEntryEntity` and a `claimBatch(now, staleBefore)` UPDATE…RETURNING-style two-step in the DAO. Add a client-generated `id` (UUID) to `MessageInsertDto`/`ChatMessagePayload` so re-sends are idempotent server-side.
- Test: Robolectric + in-memory Room: enqueue 3 rows, start two `OutboxWorker` instances concurrently (`TestListenableWorkerBuilder`) with a fake handler that suspends 200 ms and records `entry.id`; assert each id handled exactly once and `attempts` never exceeds 1 per failure.
- Owner: ME

### SSB-02 [HIGH] `ExistingWorkPolicy.REPLACE` on the one-shot cancels an in-flight drain mid-request → committed writes re-execute; the photo handler triggers it from inside its own drain
- File: app/src/main/kotlin/com/equipseva/app/core/sync/OutboxEnqueuer.kt:54-58; app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:64-70; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:138-145
- What: Every `enqueue()` REPLACEs the running one-shot, cancelling its coroutine at the next suspension point. If the cancelled handler had already sent its HTTP request (Postgrest insert/RPC committed server-side), the entry survives with unchanged `attempts` and is re-sent by the next run — a duplicate chat message / repeated status transition. `PhotoUploadOutboxHandler` itself calls `outbox.enqueue(EVIDENCE_REGISTER)` while running inside the one-shot, so a successful photo upload always cancels the drain that produced it (rest of the batch aborted; the photo entry is re-visited next run as "Local file missing" GiveUp).
- Evidence: `workManager.enqueueUniqueWork(UNIQUE_NAME + "-oneshot", ExistingWorkPolicy.REPLACE, request)`; worker re-throws `CancellationException` (correct) so the entry is neither deleted nor marked; `chatRepository.sendMessage` = plain `insert(payload) { select() }` with no idempotency key.
- Fix: Use `ExistingWorkPolicy.APPEND_OR_REPLACE` (or `KEEP` — the loop re-reads `nextBatch()` on the next run anyway) for the one-shot; never REPLACE running work. Pair with the SSB-01 idempotency key.
- Test: `WorkManagerTestInitHelper`-based test: enqueue A, start the worker with a fake handler suspended on a `CompletableDeferred`, enqueue B while suspended, then complete; assert the first worker was not cancelled and the handler ran once per entry.
- Owner: ME

### SSB-03 [HIGH] Cold-start "no session yet" is charged against the 5-attempt budget for every pending row → queued writes poison-dropped while the user is signed in and online
- File: app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:77-96; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:60-63; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/EvidenceRegisterOutboxHandler.kt:52-55; app/src/main/kotlin/com/equipseva/app/core/data/chat/ChatMessageOutboxHandler.kt:42-45; app/src/main/kotlin/com/equipseva/app/core/data/repair/RepairBidOutboxHandler.kt:33-36; app/src/main/kotlin/com/equipseva/app/core/data/repair/JobStatusOutboxHandler.kt:39-42
- What: WorkManager routinely cold-starts the process for the periodic tick. supabase-kt loads the persisted session asynchronously (`SessionStatus.Initializing`; EncryptedSharedPreferences + Keystore, plus a network refresh when the access token expired — the normal case after >1 h idle). Every handler reads `supabase.auth.currentUserOrNull()`, gets `null`, returns `Retry(IllegalStateException("No auth session"))`, and the worker calls `markFailed` (+1) for each row. The same happens on `SessionStatus.RefreshFailure`. Five such ticks (~75 min of background life) delete every queued chat message, bid and status change and post "Couldn't send…" notifications although nothing was ever attempted.
- Evidence: `is OutboxKindHandler.Outcome.Retry -> { val nextAttempts = entry.attempts + 1; if (nextAttempts >= MAX_ATTEMPTS) {…notifyPoisonDrop…delete} else outbox.markFailed(…) }` with no distinction for the not-ready case; `SupabaseAuthRepository.kt:33` maps `Initializing -> AuthSession.Unknown`, confirming the window exists.
- Fix: At the top of `doWork()` call `supabase.auth.awaitInitialization()` (bounded with `withTimeoutOrNull`) and, if there is still no session, return `Result.retry()` without touching any row. Additionally give `Outcome.Retry` a `countsAgainstBudget: Boolean` (false for the no-session case) so handlers cannot burn attempts on a precondition.
- Test: Worker unit test with a fake `Auth` whose `sessionStatus` stays `Initializing`: assert `doWork()` returns `Result.retry()` and `attempts` is unchanged for all rows; second test flips to `Authenticated` after 100 ms and asserts the handler ran.
- Owner: ME

### SSB-04 [HIGH] `ScrubbedException` keeps the unscrubbed original as `cause` → Crashlytics receives the PII anyway; nested causes are never scrubbed
- File: app/src/main/kotlin/com/equipseva/app/core/observability/CrashReporter.kt:26-27, 40-46, 64-70
- What: `wrapScrubbedThrowable` redacts only the top-level `message` and wraps it in `ScrubbedException(originalType, scrubbedMessage, cause = t)`. `FirebaseCrashlytics.recordException` serialises the full cause chain, so the original exception with its raw message (emails/phones/JWT/`token=` in supabase-kt `RestException` messages, which embed the request URL) ships to Crashlytics under a "redacted" wrapper. When the top message is clean the throwable is returned as-is, so a PII-bearing *cause* (repository wraps → RestException) is never scrubbed. Sentry is covered by `SentryInitializer.scrubEvent` (it rewrites `event.exceptions`), Crashlytics has no such hook.
- Evidence: `return ScrubbedException(t::class.java.name, scrubbedMessage, t)` and `if (scrubbedMessage == t.message) return t`; `FirebaseCrashlytics.getInstance().recordException(safeThrowable)`.
- Fix: Rebuild the chain: for each throwable in the cause chain create a `ScrubbedException(type, scrub(message), null)`, copy `stackTrace` via `setStackTrace`, link the scrubbed copies as causes, never reference the originals. Apply the same recursion regardless of whether the top message changed.
- Test: `wrapScrubbedThrowable(RuntimeException("wrapper", RuntimeException("user a@b.com phone 9876543210")))` → walk `generateSequence(result) { it.cause }` and assert no message matches the email/phone regexes and every element is a `ScrubbedException` or PII-free.
- Owner: ME

### SSB-05 [HIGH] R8 `mapping.txt` published to a PUBLIC GitHub Release and as a public CI artifact — de-obfuscation map for anyone
- File: .github/workflows/release-aab.yml:153-165, 183-186; .github/workflows/android.yml:166-172
- What: The repo is public (`api.github.com/repos/ganeshnaik166/equipseva-android` → `"visibility": "public"`). `release-aab.yml` uploads `mapping.txt` next to the signed AAB on the tag's Release; `android.yml` uploads `release-mapping` on every push. With the map, every R8 full-mode obfuscation the project relies on for anti-tamper (`gradle.properties` "raising the cost of jadx/ghidra", the three integrity-check layers) is undone; attackers get the exact signed bundle plus its symbol map.
- Evidence: `gh release upload "$TAG" "${{ steps.artifacts.outputs.mapping }}" --clobber`; `name: release-mapping … path: app/build/outputs/mapping/release/mapping.txt` with `if: always()`.
- Fix: Delete both mapping uploads (Sentry already receives the mapping via the Gradle plugin when `SENTRY_*` are set; Crashlytics gets it via the Firebase plugin). If a copy must be kept, store it in a private artifact store, not a public Release. Consider whether the AAB itself belongs on a public Release.
- Test: A CI lint step (`scripts/verify/workflow_guards.sh`) that greps `.github/workflows/*.yml` for `mapping` in any `upload`/`upload-artifact` step and fails.
- Owner: ME

### SSB-06 [MEDIUM] Retry budget is wall-clock-tick based and the configured exponential backoff is dead code — ~75 min of any transient failure permanently drops queued writes
- File: app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:48-101, 133; app/src/main/kotlin/com/equipseva/app/core/sync/OutboxEnqueuer.kt:48-52; app/src/main/kotlin/com/equipseva/app/core/sync/SyncModule.kt:47-51
- What: `doWork()` always returns `Result.success()`, so `setBackoffCriteria(EXPONENTIAL, 30s)` on both requests never applies (backoff only follows `Result.retry()`), and the comments claiming it "lets transient outages breathe" are false. Failed entries are only re-tried by the 15-minute periodic tick, and each tick costs one of `MAX_ATTEMPTS = 5`. Any Supabase-side outage, PostgREST schema-cache reload window, or `RefreshFailure` lasting ~75 min deletes the queue with a "Couldn't send…" notification — while the classifier already routes permanent errors to `GiveUp`, so the transient path is being capped by time, not by evidence of poison.
- Evidence: single `return Result.success()` at line 100; `MAX_ATTEMPTS = 5`; `PeriodicWorkRequestBuilder<OutboxWorker>(15, TimeUnit.MINUTES)`.
- Fix: Return `Result.retry()` when any entry produced `Retry` (so the one-shot actually backs off exponentially) and make poison detection age-aware: drop only when `attempts >= N && now - createdAt >= 24h`; raise `MAX_ATTEMPTS` to something like 20. Keep the notification.
- Test: Worker test with a fake handler returning `Retry(IOException)` → assert `Result.retry()`; second test: `attempts = 19, createdAt = now - 1h` → still retained; `createdAt = now - 25h` → dropped with notification.
- Owner: ME

### SSB-07 [MEDIUM] `classifyOutboxError` treats HTTP 401 as permanent — an expired/unrefreshed JWT deletes the queued write silently
- File: app/src/main/kotlin/com/equipseva/app/core/sync/OutboxErrorClassifier.kt:38-48
- What: Only 408/429 are exempted from the 4xx → `GiveUp` rule. PostgREST returns 401 (`PGRST301 JWT expired`) when the access token is stale — exactly the state of a background drain after idle (the r3816 idle-refresh bug class). `GiveUp` deletes the row with a log line only (no user notification, unlike poison-drop), so a chat message/bid vanishes. 401 is ambiguous (revoked refresh token is permanent), so it must be retried once after a forced refresh, not dropped on first sight.
- Evidence: `error.statusCode in 400..499 -> Outcome.GiveUp("Permanent ${error.statusCode}: …")`.
- Fix: `401 -> Retry(error)` (and have the worker call `supabase.auth.refreshCurrentSession()` once per run when it sees one); keep 403 as `GiveUp`. Optionally treat 409 as `Success` once idempotency keys (SSB-01) exist.
- Test: Extend the existing classifier test (MockEngine-built `RestException`) with `statusCode = 401` → `Retry`; `403` → `GiveUp`.
- Owner: ME

### SSB-08 [MEDIUM] `NotificationReadOutboxHandler` GiveUps when the session is `Unknown`/`SignedOut` (every other handler Retries) — cold-start drains permanently drop mark-reads
- File: app/src/main/kotlin/com/equipseva/app/core/data/notifications/NotificationReadOutboxHandler.kt:39-47, 93-100
- What: It resolves the user via `authRepository.sessionState.first()`; at WorkManager cold start that is `AuthSession.Unknown` (`SupabaseAuthRepository.kt:33`) and on a transient `RefreshFailure` it is `SignedOut` (line 34). `notificationReadOwnerGateReason(owner, null)` returns a drop reason, so the entry is deleted as a "cross-user" case although no user switch happened. The four sibling handlers return `Retry` for the same state. Also its `runCatching { withTimeout { … } }` swallows the parent worker's `CancellationException` (see SSB-13).
- Evidence: `queuedOwner == currentUserId -> null; else -> "Cross-user notif read drop (queued=$queuedOwner, current=$currentUserId)"` with `currentUserId` nullable and no `null -> Retry` branch.
- Fix: `if (uid == null) return Retry(IllegalStateException("No auth session — deferring mark-read"))` before the gate; replace `runCatching` with try/catch that re-throws `CancellationException` (keep catching `TimeoutCancellationException` → Retry).
- Test: Handler test with a fake `AuthRepository` emitting `Unknown` → expects `Retry`; emitting `SignedIn(other)` → `GiveUp`; pin `notificationReadOwnerGateReason` no longer receives null.
- Owner: ME

### SSB-09 [MEDIUM] Stashed photo/KYC bytes leak on every non-success terminal path (GiveUp, poison-drop, unknown kind)
- File: app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:56-82, 111-117 (vs 150-152); app/src/main/kotlin/com/equipseva/app/core/sync/OutboxWorker.kt:54-57, 73-76, 92-93
- What: Only the `Success` path deletes `payload.localFilePath`. Malformed payload, uploader mismatch, empty/oversized file, `UploadError`, storage 4xx, the worker's poison-drop and the unknown-kind drop all delete the outbox row but leave the file in `filesDir/photo-outbox/`. KYC documents (Aadhaar/PAN scans, up to 15 MB) therefore persist on disk indefinitely for users who never sign out; `SignOutCleanup.photoUploadStash.clearAll()` is the only reclaim path. The class doc's own goal ("we don't want in-flight KYC docs … on device") is violated.
- Evidence: e.g. `if (currentUid != payload.uploaderUserId) return GiveUp("Uploader mismatch…")` — no `file.delete()`; `return classifyOutboxError(uploadError)` — no cleanup; worker `notifyPoisonDrop(entry.kind); outbox.delete(entry.id)` never informs the handler.
- Fix: In the handler, route every `GiveUp` through a `dropWithCleanup(payload)` helper that deletes the stash file. Add `suspend fun onDropped(entry)` (default no-op) to `OutboxKindHandler`, called by the worker before poison/unknown-kind deletes; implement it for `PHOTO_UPLOAD`. Also sweep `photo-outbox/` for files older than 7 days at app start.
- Test: Handler test with a temp file and `uploaderUserId != currentUid` → assert `GiveUp` and `!file.exists()`; worker test with a handler returning `Retry` 5× → assert `onDropped` invoked once.
- Owner: ME

### SSB-10 [MEDIUM] `ReverseEngineeringDetector` is structurally dead on Android 11+ — no `<queries>` declarations, so every probe reads "not installed"
- File: app/src/main/kotlin/com/equipseva/app/core/security/ReverseEngineeringDetector.kt:14-19, 73-89; app/src/main/AndroidManifest.xml:19-24
- What: With `targetSdk = 35`, package-visibility filtering makes `pm.getPackageInfo(pkg, 0)` throw `NameNotFoundException` for any package not declared in `<queries>` — including installed ones. The manifest's only `<queries>` entry is an `https` VIEW intent. The KDoc asserts the opposite ("works without the manifest tags because we're checking specific known packages"). Result: `re=0` in every integrity header, `reBlocked` can never trigger even with `TAMPER_ENFORCE=true`, and LSPosed/Frida/Lucky Patcher presence is invisible.
- Evidence: `runCatching { pm.getPackageInfo(pkg, 0); true }.recover { ex -> if (ex is NameNotFoundException) false … }`; manifest lines 19-24 contain no `<package android:name=…/>`.
- Fix: Add `<queries>` with one `<package android:name="…"/>` per entry of `SUSPICIOUS_PACKAGES` (33 entries; well under Play's review threshold, unlike `QUERY_ALL_PACKAGES`).
- Test: Unit test that parses `app/src/main/AndroidManifest.xml` and asserts the set of `<package>` names ⊇ `ReverseEngineeringDetector.SUSPICIOUS_PACKAGES` (make the list `internal`).
- Owner: ME

### SSB-11 [MEDIUM] Keystore key loss makes the SQLCipher DB permanently unopenable — crash loop until "Clear storage"
- File: app/src/main/kotlin/com/equipseva/app/core/data/secure/DbPassphraseStore.kt:27-42; app/src/main/kotlin/com/equipseva/app/core/data/AppDatabase.kt:72-90
- What: When `unseal()` fails (Keystore reset/OEM quirk — the exact case the KDoc anticipates), `getOrCreate()` deletes the sealed file and mints a fresh passphrase, but the caller never wipes `equipseva.db`. Room then opens an existing SQLCipher file with the wrong key → `SQLiteException: file is not a database` on first DB access, every launch. `provideDatabase` only wipes when the file is *plaintext*. The DB is documented as "cache + outbox, not canonical state", so a wipe is the intended recovery — it just isn't implemented.
- Evidence: `.onFailure { sealedFile.delete() }; return freshPassphrase()` with no DB wipe; `if (plain.exists() && !isEncrypted(plain)) { … delete }` is the only wipe.
- Fix: Make `getOrCreate()` return whether a fresh passphrase was minted (or expose `unsealFailed`), and in `provideDatabase` delete `equipseva.db`, `-wal`, `-shm` in that case before building; additionally catch the first open failure and wipe+retry once.
- Test: Robolectric: build DB with passphrase A, overwrite `db-passphrase.bin` with garbage, call `provideDatabase` → assert it opens and `outboxDao().nextBatch()` returns empty instead of throwing.
- Owner: ME

### SSB-12 [MEDIUM] Hourly/code-red/payouts/keepalive workflows print raw response bodies into public Actions logs
- File: .github/workflows/cron-tick-hourly.yml:62-69; .github/workflows/cron-tick-code-red.yml:50-57; .github/workflows/engineer-payouts-worker.yml:73-80; .github/workflows/supabase-keepalive.yml:44-45 (contrast .github/workflows/cron-tick-daily.yml:60-71)
- What: The daily workflow was hardened so that "Raw response content and curl errors must never reach Actions logs or summaries" (body to `$RUNNER_TEMP`, summarizer prints only status). The sibling workflows still run `curl --fail-with-body … --silent --show-error` with stdout attached, so the full cron-tick / payouts-worker JSON (job ids, payout rows, per-slot results, error details) lands in logs that are world-readable on this public repository; the keepalive step additionally echoes 200 bytes of `repair_jobs` data.
- Evidence: `curl --fail-with-body --silent --show-error --max-time 60 -X POST "$URL" …` with no `--output`; `head -c 200 /tmp/body`.
- Fix: Reuse the daily pattern: `--output "$RESPONSE_BODY" --write-out '%{http_code}'`, then `python3 scripts/cron_response_summary.py …`; drop the `head -c 200` echo.
- Test: Workflow guard script asserting every `curl` invocation in `.github/workflows/*.yml` includes `--output`; extend `scripts/test_cron_response_summary.py` to cover the hourly and payouts shapes.
- Owner: ME

### SSB-13 [MEDIUM] `CancellationException` swallowed in four places — one can silently skip the §65B evidence registration
- File: app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:139-144; app/src/main/kotlin/com/equipseva/app/core/data/notifications/NotificationReadOutboxHandler.kt:53-65; app/src/main/kotlin/com/equipseva/app/core/security/PlayIntegrityClient.kt:81-83, 94-99; app/src/main/kotlin/com/equipseva/app/core/location/LocationFetcher.kt:93-98
- What: (a) `runCatching { outbox.enqueue(EVIDENCE_REGISTER…) }` — if the worker is cancelled (sign-out `cancelAll()`, WorkManager stop, SSB-02 REPLACE) while the Room insert is suspended, the exception is logged as a warning, `file.delete()` runs, `Success` is returned; the entry lingers, the next run hits "Local file missing" → GiveUp, and the photo is on the job with no ledger row — exactly the "compliant-on-paper" gap the class doc says must never be silent. (b) `NotificationReadOutboxHandler` wraps `withTimeout` in `runCatching`, converting the worker's cancellation into `Retry` + attempts burn. (c) `PlayIntegrityClient` — `withTimeoutOrNull { runCatching { … } }` turns caller cancellation into `success(true)` in debug / `failure` in release. (d) `LocationFetcher` legacy path `catch (_: Throwable)` inside `withTimeoutOrNull`.
- Evidence: `runCatching { outbox.enqueue(kind = …EVIDENCE_REGISTER, payloadJson = …) }.onFailure { Log.w(…) }`; `return runCatching { kotlinx.coroutines.withTimeout(MARK_READ_TIMEOUT_MS) { … } }.fold(…, onFailure = ::classifyOutboxError)`.
- Fix: Replace each `runCatching`/`catch (Throwable)` around suspending code with try/catch that re-throws `CancellationException` (except `TimeoutCancellationException` where a timeout is intended). For (a), enqueue the evidence row inside the same Room transaction that deletes the photo entry, or before `file.delete()` with no catch at all.
- Test: Handler tests that cancel the calling scope while a fake `OutboxEnqueuer`/repository is suspended and assert `CancellationException` propagates (JUnit `assertFailsWith`) and `file.exists()` is still true.
- Owner: ME

### SSB-14 [LOW] Frida probe runs a TCP connect on the main thread → `NetworkOnMainThreadException` swallowed → always "clean" at boot and on foreground
- File: app/src/main/kotlin/com/equipseva/app/core/security/DeviceIntegrityCheck.kt:148-158; app/src/main/kotlin/com/equipseva/app/EquipSevaApplication.kt:103, 175
- What: `looksLikeFrida()` does `Socket().connect(127.0.0.1:27042)`; on the main thread (called synchronously from `Application.onCreate` and the `ProcessLifecycleOwner.onStart` observer) Android throws `NetworkOnMainThreadException` even for loopback, `runCatching` returns `false`, so only the 15-minute IO-dispatcher loop can ever detect Frida. Root/emulator probes also do disk I/O on the main thread.
- Evidence: `return runCatching { Socket().use { s -> s.connect(InetSocketAddress("127.0.0.1", port), 50); true } }.getOrDefault(false)` with callers on the main thread.
- Fix: Run `DeviceIntegrityCheck.run(context)` on `Dispatchers.IO` (make the boot/foreground checks a coroutine on `appScope` that captures the snapshot when done), or make the Frida probe use a dedicated thread with a join timeout.
- Test: Robolectric test with `StrictMode.setThreadPolicy(penaltyDeath on network)` on the test main thread asserting `run(context)` completes and that the frida probe executed off-main (record `Thread.currentThread()` via a test hook).
- Owner: ME

### SSB-15 [LOW] `TAMPER_ENFORCE` has no path into the release build — the documented "flip via CI secret" is a no-op
- File: .github/workflows/release-aab.yml:100-116; app/build.gradle.kts:107-111; app/src/main/kotlin/com/equipseva/app/core/security/SignatureVerifier.kt:34-38
- What: The flag is read from `local.properties`/env `TAMPER_ENFORCE`, but the release workflow writes neither; no `vars`/`secrets` plumbing exists. Every CI-built AAB is therefore report-only regardless of what the operator sets, while comments/runbook describe enforcement as a switch to flip after the Play SHA is added. `SignatureVerifier` also returns `Unknown` (pass) when the SHA list is blank, so a missing secret is silent at runtime (the strict `preReleaseCheck` catches only the blank-SHA case).
- Evidence: local.properties heredoc lists `SUPABASE_URL … MAPS_API_KEY` and nothing else; `buildConfigField("boolean", "TAMPER_ENFORCE", flag.toString())`.
- Fix: Add `TAMPER_ENFORCE=${{ vars.TAMPER_ENFORCE }}` to the local.properties step and extend `scripts/pre-release-checks.sh` to fail (strict mode) when `TAMPER_ENFORCE` is not `true` once both SHAs are present.
- Test: Shell test for `pre-release-checks.sh` with a fixture `local.properties` (SHA set, enforce unset) expecting exit 1 in strict mode.
- Owner: ME

### SSB-16 [LOW] `Validators.indiaMobileError` rejects valid mobiles that start with "91"
- File: app/src/main/kotlin/com/equipseva/app/core/util/Validators.kt:62-73
- What: `trimmed.removePrefix("+91").removePrefix("+").removePrefix("91")` strips a leading "91" from bare 10-digit numbers, so `9123456789` (a valid 9-series Indian mobile) becomes 8 digits → "Enter 10 digits". Affects the hospital reception / biomed contact fields.
- Evidence: the third `removePrefix("91")` applies to input that never had a country code.
- Fix: Strip the country code only when it is prefixed by `+` or when the remaining digit count is exactly 10 after stripping (`if (digits.length == 12 && digits.startsWith("91")) digits = digits.drop(2)`).
- Test: `assertNull(Validators.indiaMobileError("9123456789"))`; keep `"+919123456789"` and `"919123456789"` passing.
- Owner: ME

### SSB-17 [LOW] `openExternalUrl` pins the intent to the system resolver's package when no default browser is set → false "No browser found"
- File: app/src/main/kotlin/com/equipseva/app/core/util/UrlIntents.kt:21-29
- What: `pm.resolveActivity(probe, MATCH_DEFAULT_ONLY)` returns the `ResolverActivity` (package `android`) when several browsers exist and none is default; the code then `setPackage("android")` on the VIEW intent, which resolves nothing → `ActivityNotFoundException` → toast, so legal/help links fail on multi-browser devices without a default.
- Evidence: `?.activityInfo?.packageName?.takeIf { it != ctx.packageName }` — no exclusion of `android`/resolver.
- Fix: Use `pm.queryIntentActivities(probe, MATCH_DEFAULT_ONLY).map { it.activityInfo.packageName }.filter { it != ctx.packageName && it != "android" }`; if exactly one → `setPackage`, otherwise use `Intent.createChooser` or `addCategory(CATEGORY_BROWSABLE)` with the app's own host excluded via `FLAG_ACTIVITY_REQUIRE_NON_BROWSER`-style logic.
- Test: Robolectric with two shadow browser activities, no preferred activity → assert the started intent has `package == null` and no toast.
- Owner: ME

### SSB-18 [LOW] `ChangeEmailViewModel` reports every re-auth failure (network, 5xx, "not signed in") as "Current password is incorrect."
- File: app/src/main/kotlin/com/equipseva/app/features/security/ChangeEmailViewModel.kt:114-123 (contrast ChangePasswordViewModel.kt:117-124)
- What: `if (reauth.isFailure) passwordError = "Current password is incorrect."` — `verifyCurrentPassword` throws `IllegalStateException("Not signed in")`, `HttpRequestException`, etc. for non-password causes; the sibling password screen branches on `InvalidCurrentPasswordException`. Users on a flaky link are told their password is wrong.
- Evidence: no `is InvalidCurrentPasswordException` check in the email VM.
- Fix: Mirror `ChangePasswordViewModel`: `InvalidCurrentPasswordException` → `passwordError`; anything else → `errorMessage = ex.toUserMessage()`.
- Test: VM test with a fake `AuthRepository.verifyCurrentPassword` returning `Result.failure(IOException())` → assert `passwordError == null && errorMessage != null`.
- Owner: ME

### SSB-19 [LOW] CI coverage/permission gaps: active `claudedev-*` branches excluded, several workflows without `permissions:`, mutable third-party action tag
- File: .github/workflows/android.yml:8; .github/workflows/secret-scan.yml:12; .github/workflows/evidence-regressions.yml:14; .github/workflows/cron-tick-hourly.yml (no `permissions`); .github/workflows/check-assetlinks.yml (no `permissions`); .github/workflows/supabase-keepalive.yml (no `permissions`); .github/workflows/secret-scan.yml:30
- What: Branch filters list `claudedev-help` literally, so `claudedev-auth-audit`, `claudedev-quality-*`, `claudedev-next-review-*` (all active per project notes) get no build, no unit tests and no gitleaks. Three workflows inherit the repo-default token scope instead of `contents: read`. `gitleaks/gitleaks-action@v3` (third-party, receives `GITHUB_TOKEN` with `pull-requests: write`) is referenced by mutable tag while `evidence-regressions.yml` pins SHAs.
- Evidence: `branches: [main, "ops/**", "codex/**", "claudedev-help"]`; hourly workflow has `concurrency:` but no `permissions:`.
- Fix: `"claudedev-**"` in all three filters; add `permissions: contents: read` to the three workflows; pin `gitleaks-action` to a commit SHA.
- Test: Workflow guard script asserting every workflow has a top-level `permissions:` and that `uses:` lines for non-`actions/` owners are SHA-pinned.
- Owner: ME

### SSB-20 [LOW] Unfiltered Ktor EAP repository in dependency resolution
- File: settings.gradle.kts:20
- What: `maven("https://maven.pkg.jetbrains.space/public/p/ktor/eap")` is searched for every coordinate that Google/Maven Central do not serve, with no `content { includeGroup("io.ktor") }` filter. Ktor 3.4.3 (catalog) is a Central release, so the repo is unnecessary and widens the dependency-confusion surface for any future typo'd/unpublished coordinate.
- Evidence: plain `maven(...)` under `dependencyResolutionManagement.repositories`.
- Fix: Remove the repository; if an EAP is ever needed, add it with `content { includeGroupByRegex("io\\.ktor.*") }` and `mavenContent { snapshotsOnly() }`.
- Test: Guard test/grep in CI that `settings.gradle.kts` contains no `maven(` without a `content {` block.
- Owner: ME

### SSB-21 [LOW] Evidence-registration owner mismatch is dropped without observability, contrary to the handler's own contract
- File: app/src/main/kotlin/com/equipseva/app/core/sync/handlers/EvidenceRegisterOutboxHandler.kt:56-60 (vs 105-110)
- What: A `producerUserId` mismatch returns `GiveUp` without `crashReporter.report`, while the class doc requires every permanent registration failure to reach observability because "evidence that silently fails to register is exactly the compliant-on-paper failure the ledger exists to end". Same for the client-side sha/size rejection at 61-65 and the sentinel `Retry` on no-session after 5 ticks.
- Evidence: `if (currentUid != payload.producerUserId) return GiveUp("Producer mismatch…")` — no reporter call.
- Fix: Report via `crashReporter.report(IllegalStateException("evidence_register dropped"), reason)` on every `GiveUp` branch (uuids only, no PII).
- Test: Handler test with mismatched uid asserting the fake `CrashReporter` received one report.
- Owner: ME

### SSB-22 [LOW] 60 s upload timeout cannot accommodate the 15 MB stash cap on slow links → deterministic poison-drop of large KYC documents
- File: app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:93-110; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadPayload.kt:51
- What: The timeout is sized for "a 3 MB upload on a 2G-grade link"; the payload cap is 15 MB (KYC bucket). A legitimately large PDF on the same link times out every attempt (`Retry`), restarts from byte 0 (no resumable upload), and after 5 ticks is dropped with "Couldn't upload a photo" — re-attaching reproduces it.
- Evidence: `UPLOAD_TIMEOUT_MS = 60_000L` vs `MAX_FILE_SIZE_BYTES = 15L * 1024 * 1024`.
- Fix: Scale the timeout with size (e.g. `30s + 20s/MB`, capped by WorkManager's 10-minute budget) or use Supabase resumable (TUS) uploads for files > 3 MB.
- Test: Unit test on a pure `uploadTimeoutFor(sizeBytes)` helper pinning 3 MB → 90 s, 15 MB → ≥ 330 s, and an upper cap.
- Owner: ME

---

Verified-clean areas:
- `OutboxErrorClassifier`: IOException/HttpRequestException/5xx → Retry, 408/429 exempted, `UploadError` and `SerializationException` → GiveUp; handlers re-throw `CancellationException` around network calls (except SSB-13 sites); bounded `withTimeout` on every handler's network call.
- Owner gates present on all five outbox kinds with payload-embedded owner ids; legacy null-owner policies are explicit and pinned (strict for `JOB_STATUS`, lenient for bid/notification) — documented asymmetry, not a defect. `SignOutCleanup` clears outbox rows, stash files, schedules, prefs, pending-payment stores and realtime channels before the network sign-out.
- Payload evolution: all payload additions are nullable-with-default; injected `Json` has `ignoreUnknownKeys = true`, so older/newer builds decode each other's rows; unknown `kind` and unknown `RepairJobStatus` are dropped deliberately. No explicit `version` field, but none is currently required.
- WorkManager wiring: Hilt `HiltWorkerFactory` + manifest removal of the default initializer; `NetworkType.CONNECTED` (validated network on API 26+, minSdk 26); periodic uses `ExistingPeriodicWorkPolicy.UPDATE`; `POST_NOTIFICATIONS` runtime check before notifying.
- Storage at rest: session tokens in Keystore-backed `EncryptedSharedPreferences` (AES256-GCM values, AES256-SIV keys) with a volatile-only fallback that never writes plaintext; Room under SQLCipher with a Keystore-wrapped random passphrase; `allowBackup="false"` plus exclude-all `backup_rules.xml` / `data_extraction_rules.xml`; `SecurePrefs` invariant documents its plaintext fallback as cache-grade only.
- PII in telemetry: supabase-kt log level pinned to INFO (refresh-token leak documented and avoided); no `Log.*` statement in `app/src/main` interpolates token/password/email/phone/otp values (grep); Sentry `sendDefaultPii=false`, `beforeSend`/`beforeBreadcrumb` scrub messages, URLs, `data` values and drop `/auth/v1/` HTTP crumbs; only the Supabase UUID + role are attached as user context in both SDKs.
- Network security config: cleartext disabled, system CAs only, intermediate+root pin-sets for `supabase.co` and `razorpay.com` expiring 2027-12-31; debug overrides kept out of `main` resources.
- BuildConfig/secrets: only public identifiers are baked (Supabase URL/anon key, Sentry DSN, Google web client id, cert hash, Maps key via placeholder); no Razorpay key, service-role key or cron secret in the APK; `razorpay_api_key` string is blank by design; release-aab.yml passes secrets via `env`, never echoes them, verifies presence, and re-runs tests + lint before signing.
- Manifest: only `MainActivity` is exported (launcher + verified App Links with path filters); FCM service, FileProvider (cache-scoped paths) and startup provider are `exported="false"`; permissions limited to INTERNET/NETWORK_STATE/POST_NOTIFICATIONS/WAKE_LOCK/CAMERA/location.
- ProGuard/R8: keep rules present for app `@Serializable` classes, Hilt, Room, SQLCipher JNI, Razorpay (incl. `JavascriptInterface`), Firebase, Sentry, Play Integrity; `Log.w/e` retained; release R8 builds are validated in CI and shipped to production, so no evidence of a missing keep rule.
- `PlayIntegrityClient`: token decoded server-side only, fail-closed in release, random per-call nonce, 10 s/15 s bounds; debug fail-open is intentional and gated on `BuildConfig.DEBUG`.
- `SignatureVerifier`/`InstallSourceVerifier`/`IntegritySnapshot`: correct API-level branches, null-safe signer access, header attached to every Supabase request via `defaultRequest`.
- `LocationFetcher`/`fetchCurrentLocation`: permission-checked, bounded by timeouts, cancellable continuations; `CurrentLocation` propagates cancellation to the Play Services token.
- `features/security`: re-auth gate before contact-email change and password change, `FLAG_SECURE` screens, input length caps, replay-0 effects, strength policy shared with sign-up.
- Workflows otherwise: Gradle steps fail on non-zero exit; `set -euo pipefail` + `--fail-with-body` on cron posts; daily cron-tick body sanitized; payouts canary `permissions: issues: write` present (effective once on main); `cancel-in-progress` scoped per ref.
