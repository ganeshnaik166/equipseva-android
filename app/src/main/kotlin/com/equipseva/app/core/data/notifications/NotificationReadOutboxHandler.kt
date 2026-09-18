package com.equipseva.app.core.data.notifications

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued notification mark-read mutations. The optimistic update
 * lives in the VM/UI; this handler is purely about getting the
 * `read_at` column to flip server-side once the network is back so the
 * row doesn't bounce back to unread on the next realtime sync.
 *
 * Owner gate: when the queued payload carries a `userId`, the handler
 * compares it to the currently-signed-in user before draining. If a
 * different account is signed in (shared device case), the row is
 * dropped with GiveUp so the next user doesn't waste a retry-budget
 * attempt round-tripping a row that RLS will reject anyway. Rows
 * enqueued before this field existed have `userId = null` and fall
 * through to RLS-only protection — same behavior as before.
 *
 * "No signed-in user at all" is a different situation from an account
 * switch and is deferred, never dropped: the session is still restoring
 * at WorkManager cold start, and a refresh failure that clears itself on
 * the next tick looks identical from here.
 */
class NotificationReadOutboxHandler @Inject constructor(
    private val notificationRepository: NotificationRepository,
    private val authRepository: AuthRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching {
            json.decodeFromString<NotificationReadPayload>(entry.payload)
        }.getOrElse {
            return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}")
        }
        // "Which user is this" has to be answered before the owner gate can
        // mean anything. At WorkManager cold start the session is still
        // restoring (`Unknown`) and a transient refresh failure reads as
        // `SignedOut`, and in both states this handler used to hand a null
        // current user to the gate, which reported a cross-user drop and
        // deleted the row — although no account switch had happened and every
        // sibling handler defers in exactly the same state. Mark-reads then
        // vanished and the notification bounced back to unread on the next
        // sync, repeatedly.
        val current = authRepository.sessionState.first()
        val uid = (current as? AuthSession.SignedIn)?.userId
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring mark-read"),
                countsAgainstBudget = false,
            )
        val dropReason = notificationReadOwnerGateReason(payload.userId, uid)
        if (dropReason != null) {
            return OutboxKindHandler.Outcome.GiveUp(dropReason)
        }
        // Bound the RPC like the chat / bid / job-status handlers
        // do. Without it, a hung TLS connection burns the whole attempts
        // budget on the same broken socket and the mark-read poison-drops
        // without surfacing why. 15s matches ChatMessageOutboxHandler's
        // SEND_TIMEOUT_MS.
        //
        // That timeout is the only cancellation this handler owns. One from
        // outside (WorkManager stopping the drain, sign-out cancelling the
        // work) has to propagate instead: absorbing it reported a Retry,
        // which charged the row an attempt for the app's own shutdown.
        val result = try {
            withTimeout(MARK_READ_TIMEOUT_MS) {
                notificationRepository.markRead(payload.notificationId)
            }
        } catch (timeout: TimeoutCancellationException) {
            return OutboxKindHandler.Outcome.Retry(timeout)
        } catch (ce: CancellationException) {
            throw ce
        } catch (t: Throwable) {
            return classifyOutboxError(t)
        }
        return result.fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
    }

    companion object {
        private const val MARK_READ_TIMEOUT_MS = 15_000L
    }
}

@Serializable
data class NotificationReadPayload(
    val notificationId: String,
    // Optional + defaulted so rows queued before this field existed still
    // decode. New writes always set it; absence triggers RLS-only fallback.
    val userId: String? = null,
)

/**
 * Cross-account gate for the queued mark-read drain. Returns null when
 * the entry is safe to drain (legacy null-owner row, or owner matches
 * the currently-signed-in user) and a give-up reason string otherwise.
 *
 * Pinned semantics:
 *   * null queued owner → null (legacy row, RLS-only fallback).
 *   * null currentUserId AND non-null owner → cross-user drop (signed
 *     out / different state — never silently downgrade to "no gate").
 *     Kept as a total shape only; the caller resolves the session first
 *     and defers while there is no user, because treating "not signed in
 *     yet" as a cross-user switch deleted mark-reads at cold start.
 *   * mismatch → cross-user drop with both ids in the reason for the
 *     ops log.
 */
internal fun notificationReadOwnerGateReason(
    queuedOwner: String?,
    currentUserId: String?,
): String? = when {
    queuedOwner == null -> null
    queuedOwner == currentUserId -> null
    else -> "Cross-user notif read drop (queued=$queuedOwner, current=$currentUserId)"
}
