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
        val queuedUid = payload.engineerUserId
        if (queuedUid != null && queuedUid != currentUid) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Engineer mismatch: queued as $queuedUid, current auth is $currentUid",
            )
        }
        return bidRepository.placeBid(
            jobId = payload.jobId,
            amountRupees = payload.amountRupees,
            etaHours = payload.etaHours,
            note = payload.note,
        ).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
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
