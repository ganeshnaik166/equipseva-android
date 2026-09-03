package com.equipseva.app.features.profile

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Round 3776 — DPDP Act 2023 grievance redressal self-service
 * (round485 `file_dpdp_grievance` / `my_grievances`, unread by any
 * client until now). The migration's own header comment explains why
 * this matters: a documented grievance mechanism with an SLA is a
 * statutory obligation (§32/§33, up to ₹250 Cr penalty exposure) —
 * the backend has been "compliant on paper" since round485 but no
 * user has ever actually been ABLE to file one, since no client wired
 * it. This is genuinely the highest-stakes gap found this session.
 *
 * Scope note: `record_consent`/`current_consents` from the same
 * migration are deliberately NOT wired this round — a real consent
 * ledger needs the actual deployed ToS/Privacy-Policy
 * `document_version` strings, which is a founder/legal content
 * decision, not something to invent unilaterally.
 */
@Singleton
class DpdpGrievanceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Grievance(
        val id: String,
        @SerialName("grievance_type") val grievanceType: String,
        val description: String,
        val status: String,
        @SerialName("deadline_at") val deadlineAt: String,
        @SerialName("resolved_at") val resolvedAt: String? = null,
        @SerialName("created_at") val createdAt: String,
    )

    suspend fun fetchMyGrievances(): Result<List<Grievance>> = runCatching {
        client.postgrest.rpc(function = "my_grievances").decodeList<Grievance>()
    }

    suspend fun fileGrievance(grievanceType: String, description: String): Result<String> = runCatching {
        val raw = client.postgrest.rpc(
            function = "file_dpdp_grievance",
            parameters = buildJsonObject {
                put("p_grievance_type", JsonPrimitive(grievanceType))
                put("p_description", JsonPrimitive(description))
            },
        ).data
        raw.trim().trim('"')
    }
}
