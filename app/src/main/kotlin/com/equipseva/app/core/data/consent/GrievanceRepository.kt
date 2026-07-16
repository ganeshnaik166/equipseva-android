package com.equipseva.app.core.data.consent

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only list of DPDP grievances the current user has filed, via
 * my_grievances() (round 485) — auth.uid()-scoped (filed_by_user_id). Shows
 * status + the statutory deadline so the user can track their data-rights
 * request. Concrete @Singleton with constructor injection; no @Binds module.
 */
@Singleton
class GrievanceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Grievance(
        @SerialName("id") val id: String,
        @SerialName("grievance_type") val grievanceType: String = "",
        @SerialName("description") val description: String = "",
        // open | in_review | resolved | escalated | rejected
        @SerialName("status") val status: String = "open",
        @SerialName("deadline_at") val deadlineAt: String? = null,
        @SerialName("resolved_at") val resolvedAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    suspend fun fetch(): Result<List<Grievance>> = runCatching {
        client.postgrest
            .rpc(function = "my_grievances")
            .decodeList<Grievance>()
    }

    /**
     * Files a DPDP grievance via file_dpdp_grievance (round 485). The caller is
     * forced to auth.uid() server-side; affected_user_ids defaults to empty (not
     * needed for a self-filed data-rights request). Server re-validates the
     * description (min 10 chars) + the grievance_type enum.
     */
    suspend fun file(grievanceType: String, description: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "file_dpdp_grievance",
            parameters = buildJsonObject {
                put("p_grievance_type", JsonPrimitive(grievanceType))
                put("p_description", JsonPrimitive(description.trim()))
            },
        )
        Unit
    }
}
