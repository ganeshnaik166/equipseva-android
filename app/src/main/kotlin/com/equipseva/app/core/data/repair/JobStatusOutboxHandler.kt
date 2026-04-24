package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
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
 */
class JobStatusOutboxHandler @Inject constructor(
    private val jobRepository: RepairJobRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<JobStatusPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }
        val target = runCatching { RepairJobStatus.valueOf(payload.newStatus) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Unknown status: ${payload.newStatus}") }
        return jobRepository.updateStatus(
            jobId = payload.jobId,
            newStatus = target,
            startedAt = payload.startedAtEpochMs?.let(Instant::ofEpochMilli),
            completedAt = payload.completedAtEpochMs?.let(Instant::ofEpochMilli),
        ).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = { OutboxKindHandler.Outcome.Retry(it) },
        )
    }
}

@Serializable
data class JobStatusPayload(
    val jobId: String,
    val newStatus: String,
    val startedAtEpochMs: Long? = null,
    val completedAtEpochMs: Long? = null,
)
