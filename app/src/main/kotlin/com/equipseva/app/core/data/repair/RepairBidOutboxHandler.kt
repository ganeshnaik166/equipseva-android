package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Re-submits a repair bid that was queued when the engineer was offline.
 * Delegates to the normal [RepairBidRepository.placeBid] so the server-side
 * upsert-on-conflict semantics (one bid per engineer per job) still apply.
 */
class RepairBidOutboxHandler @Inject constructor(
    private val bidRepository: RepairBidRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<RepairBidPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }
        return bidRepository.placeBid(
            jobId = payload.jobId,
            amountRupees = payload.amountRupees,
            etaHours = payload.etaHours,
            note = payload.note,
        ).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = { OutboxKindHandler.Outcome.Retry(it) },
        )
    }
}

@Serializable
data class RepairBidPayload(
    val jobId: String,
    val amountRupees: Double,
    val etaHours: Int? = null,
    val note: String? = null,
)
