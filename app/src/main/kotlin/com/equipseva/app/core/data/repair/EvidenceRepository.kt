package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only §65B evidence ledger for one repair job (round 492):
 * evidence_for_repair_job(p_repair_job_id) — each row is a hash-chained
 * artifact (PDF, photo, signature, OTP, receipt…) with its SHA-256, size,
 * producer and capture time. Authorized server-side to the job's hospital or
 * engineer counterparty (founders see any job). Powers the Dispute Defense
 * Vault read path.
 */
@Singleton
class EvidenceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Evidence(
        @SerialName("id") val id: String,
        @SerialName("evidence_kind") val evidenceKind: String = "",
        @SerialName("content_sha256") val contentSha256: String? = null,
        @SerialName("content_size_bytes") val contentSizeBytes: Long = 0,
        @SerialName("storage_url") val storageUrl: String? = null,
        @SerialName("producer_user_id") val producerUserId: String? = null,
        @SerialName("producer_kind") val producerKind: String? = null,
        @SerialName("captured_at") val capturedAt: String? = null,
        // Forward-compat extra payload; not rendered.
        @SerialName("metadata") val metadata: JsonElement? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    suspend fun fetch(repairJobId: String): Result<List<Evidence>> = runCatching {
        client.postgrest.rpc(
            function = "evidence_for_repair_job",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        ).decodeList<Evidence>()
    }
}
