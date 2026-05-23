package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Re-submits a repair bid that was queued when the engineer was offline.
 * Delegates to the normal [RepairBidRepository.placeBid] so the server-side
 * upsert-on-conflict semantics (one bid per engineer per job) still apply.
 *
 * Owner gate: the payload carries the engineer-user-id captured at enqueue
 * time. If the active session at drain time belongs to a different user
 * (sign-out / sign-in on a shared device, account switch), the outbox row
 * is GiveUp'd so user B can't push user A's queued bid through under user
 * B's RLS context.
 */
class RepairBidOutboxHandler @Inject constructor(
    private val bidRepository: RepairBidRepository,
    private val client: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<RepairBidPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        val currentUid = client.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring bid"),
            )
        // engineerUserId may be null on rows enqueued before this field
        // was added — fall through to placeBid which still gates via
        // RLS on engineer_user_id. New rows carry the explicit id.
        val dropReason = repairBidEngineerGateReason(payload.engineerUserId, currentUid)
        if (dropReason != null) {
            return OutboxKindHandler.Outcome.GiveUp(dropReason)
        }
        // Bound the bid placement to 15s. A flaky link can hang the
        // supabase-kt client indefinitely; without a cap the worker
        // would block until poison-drop after 5 attempts.
        val result = try {
            kotlinx.coroutines.withTimeout(PLACE_BID_TIMEOUT_MS) {
                bidRepository.placeBid(
                    jobId = payload.jobId,
                    amountRupees = payload.amountRupees,
                    etaHours = payload.etaHours,
                    note = payload.note,
                )
            }
        } catch (timeout: kotlinx.coroutines.TimeoutCancellationException) {
            return OutboxKindHandler.Outcome.Retry(timeout)
        }
        return result.fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
    }

    private companion object {
        const val PLACE_BID_TIMEOUT_MS = 15_000L
    }
}

@Serializable
data class RepairBidPayload(
    val jobId: String,
    val amountRupees: Double,
    val etaHours: Int? = null,
    val note: String? = null,
    // Nullable for backward compat with rows queued before the
    // owner-gate plumbing landed; new enqueues fill this in.
    val engineerUserId: String? = null,
)

/**
 * Shared-device gate for the queued repair-bid drain. Lenient policy:
 * a null queued engineer-user-id falls through to placeBid which is
 * still gated server-side by RLS on engineer_user_id, so legacy rows
 * enqueued before the owner-gate plumbing landed still drain.
 *
 * Pinned semantics (CRITICAL — the policy asymmetry across handlers IS
 * the regression target; do not unify with [JobStatusOutboxHandler]'s
 * strict gate which drops legacy null-actor rows):
 *   * null queued engineer → null (lenient legacy fallthrough,
 *     mirroring NotificationReadOutboxHandler).
 *   * match → null (allow).
 *   * mismatch → reason string with both ids for the ops log.
 *   * "Engineer mismatch:" prefix wire-frozen so ops log filters keep
 *     matching after a refactor.
 */
internal fun repairBidEngineerGateReason(
    queuedEngineerUserId: String?,
    currentUserId: String,
): String? = when {
    queuedEngineerUserId == null -> null
    queuedEngineerUserId == currentUserId -> null
    else -> "Engineer mismatch: queued as $queuedEngineerUserId, current auth is $currentUserId"
}
