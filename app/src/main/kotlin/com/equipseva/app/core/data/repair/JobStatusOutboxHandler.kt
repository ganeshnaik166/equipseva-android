package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant
import javax.inject.Inject

/**
 * Re-applies a queued job status transition (e.g. engineer tapped "Start work"
 * or "Mark complete" while offline). Delegates to the repository's normal
 * [RepairJobRepository.updateStatus] so the sparse-write semantics (only the
 * target status + one timestamp column) are preserved.
 *
 * Timestamps in the payload capture the original user-action moment; we only
 * re-materialize `Instant` at handler-run time.
 *
 * Owner gate: the payload carries the actor user-id captured at enqueue
 * time. RLS guards the write server-side, but checking client-side first
 * gives a clean GiveUp without burning retry cycles on rows that belong
 * to a previous session.
 */
class JobStatusOutboxHandler @Inject constructor(
    private val jobRepository: RepairJobRepository,
    private val client: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<JobStatusPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }
        val target = runCatching { RepairJobStatus.valueOf(payload.newStatus) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Unknown status: ${payload.newStatus}") }

        val currentUid = client.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring status update"),
            )
        val queuedUid = payload.actorUserId
        if (queuedUid != null && queuedUid != currentUid) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Actor mismatch: queued as $queuedUid, current auth is $currentUid",
            )
        }
        return jobRepository.updateStatus(
            jobId = payload.jobId,
            newStatus = target,
            startedAt = payload.startedAtEpochMs?.let(Instant::ofEpochMilli),
            completedAt = payload.completedAtEpochMs?.let(Instant::ofEpochMilli),
        ).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
    }
}

@Serializable
data class JobStatusPayload(
    val jobId: String,
    val newStatus: String,
    val startedAtEpochMs: Long? = null,
    val completedAtEpochMs: Long? = null,
    // Nullable for backward compat with rows queued before the
    // owner-gate plumbing landed; new enqueues fill this in.
    val actorUserId: String? = null,
)
