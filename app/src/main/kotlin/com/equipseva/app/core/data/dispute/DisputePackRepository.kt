package com.equipseva.app.core.data.dispute

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject

/**
 * Dispute evidence vault (round 495): a party to a disputed repair-job escrow
 * files a structured evidence pack — a position statement plus references to
 * evidence-ledger items — which the founder later mediates. All three RPCs are
 * GRANTed to authenticated and gated server-side to the side the caller files
 * as (accepted engineer for an engineer pack, hospital owner for a hospital
 * pack). open_ auto-links any DSR/PVED for the job.
 */
@Singleton
class DisputePackRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PackEvidence(
        @SerialName("evidence_id") val evidenceId: String = "",
        @SerialName("evidence_kind") val evidenceKind: String = "",
        @SerialName("producer_kind") val producerKind: String? = null,
        @SerialName("captured_at") val capturedAt: String? = null,
        @SerialName("content_sha256") val contentSha256: String? = null,
    )

    /**
     * Opens a draft pack for [escrowId] filed as [filerRole] ('engineer' or
     * 'hospital') with a position statement (>= 20 chars) and the selected
     * evidence-ledger ids. Returns the new pack id (a scalar uuid — read from
     * the raw body and unquoted, matching the app's scalar-rpc convention).
     */
    suspend fun open(
        escrowId: String,
        filerRole: String,
        positionStatement: String,
        evidenceIds: List<String>,
    ): Result<String> = runCatching {
        client.postgrest.rpc(
            function = "open_dispute_evidence_pack",
            parameters = buildJsonObject {
                put("p_repair_job_escrow_id", JsonPrimitive(escrowId))
                put("p_filer_role", JsonPrimitive(filerRole))
                put("p_position_statement", JsonPrimitive(positionStatement.trim()))
                put("p_evidence_ledger_ids", buildJsonArray { evidenceIds.forEach { add(JsonPrimitive(it)) } })
            },
        ).data.trim().trim('"')
    }

    /** Finalizes a draft pack (draft -> submitted) so it enters mediation. */
    suspend fun submit(packId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "submit_dispute_evidence_pack",
            parameters = buildJsonObject { put("p_pack_id", JsonPrimitive(packId)) },
        )
        Unit
    }

    /** Full evidence rows attached to a pack — for the filed-confirmation view. */
    suspend fun detail(packId: String): Result<List<PackEvidence>> = runCatching {
        client.postgrest.rpc(
            function = "dispute_pack_evidence_detail",
            parameters = buildJsonObject { put("p_pack_id", JsonPrimitive(packId)) },
        ).decodeList<PackEvidence>()
    }
}
