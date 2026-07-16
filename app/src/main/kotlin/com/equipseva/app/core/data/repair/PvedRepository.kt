package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Pre-Visit Engineer Dossier (round 493): an immutable snapshot the hospital
 * reviews before granting an accepted engineer site access — masked Aadhaar,
 * verification status, certificate count, total jobs, average rating.
 * build_pved (re)issues the snapshot and returns its id; the row is then read
 * straight from pre_visit_engineer_dossiers (RLS-scoped to the job's hospital
 * or the engineer) and marked consumed on open. Both RPCs are authenticated-
 * granted and gated to the job's hospital / accepted engineer / founder.
 */
@Singleton
class PvedRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Pved(
        @SerialName("engineer_display_name") val engineerDisplayName: String = "",
        @SerialName("aadhaar_masked_id") val aadhaarMaskedId: String? = null,
        @SerialName("verification_status") val verificationStatus: String = "",
        @SerialName("verified_at") val verifiedAt: String? = null,
        @SerialName("certificate_count") val certificateCount: Int = 0,
        @SerialName("total_jobs_completed") val totalJobsCompleted: Int = 0,
        @SerialName("average_rating") val averageRating: Double? = null,
    )

    /** Build (or refresh) the dossier, read it back, and mark it consumed.
     *  Returns null if the dossier row can't be read after building. */
    suspend fun dossierForJob(repairJobId: String): Result<Pved?> = runCatching {
        val pvedId = client.postgrest.rpc(
            function = "build_pved",
            parameters = buildJsonObject { put("p_repair_job_id", JsonPrimitive(repairJobId)) },
        ).data.trim().trim('"')

        val pved = client.postgrest.from("pre_visit_engineer_dossiers")
            .select { filter { eq("id", pvedId) } }
            .decodeList<Pved>()
            .firstOrNull()

        // Best-effort: mark it opened. A failure here doesn't fail the read.
        runCatching {
            client.postgrest.rpc(
                function = "mark_pved_consumed",
                parameters = buildJsonObject { put("p_pved_id", JsonPrimitive(pvedId)) },
            )
        }
        pved
    }
}
