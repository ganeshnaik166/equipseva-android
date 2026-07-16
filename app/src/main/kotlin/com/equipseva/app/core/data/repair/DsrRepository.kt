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
 * Read-only structured Digital Service Report (DSR) for one repair job
 * (round 494): dsr_for_job(p_repair_job_id) — status, engineer/hospital
 * signatures, IEC 62353 + calibration pass flags, work summary and
 * recommendations. Party-scoped server-side (the job's hospital or engineer,
 * or a founder). 0 or 1 row per job. Complements the downloadable PDF report.
 */
@Singleton
class DsrRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Dsr(
        @SerialName("id") val id: String,
        @SerialName("status") val status: String = "",
        @SerialName("engineer_signature_at") val engineerSignatureAt: String? = null,
        @SerialName("hospital_signature_at") val hospitalSignatureAt: String? = null,
        @SerialName("iec_62353_passed") val iec62353Passed: Boolean? = null,
        @SerialName("calibration_within_oem") val calibrationWithinOem: Boolean? = null,
        @SerialName("work_summary") val workSummary: String? = null,
        @SerialName("recommendations") val recommendations: String? = null,
        // Decoded for forward-compat; not rendered on this screen.
        @SerialName("pre_post_readings") val prePostReadings: JsonElement? = null,
        @SerialName("parts_replaced") val partsReplaced: JsonElement? = null,
    )

    suspend fun fetch(repairJobId: String): Result<Dsr?> = runCatching {
        client.postgrest.rpc(
            function = "dsr_for_job",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        ).decodeList<Dsr>().firstOrNull()
    }
}
