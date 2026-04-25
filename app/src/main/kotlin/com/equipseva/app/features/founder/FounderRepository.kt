package com.equipseva.app.features.founder

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-side repo for the founder admin surface. Calls SECURITY DEFINER RPCs
 * that reject non-founders server-side, so client-only auth checks are
 * defense-in-depth — the founder dashboard becomes empty/error for impostors.
 */
@Singleton
class FounderRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PendingEngineer(
        @SerialName("user_id") val userId: String,
        @SerialName("full_name") val fullName: String,
        @SerialName("email") val email: String? = null,
        @SerialName("phone") val phone: String? = null,
        @SerialName("verification_status") val verificationStatus: String,
        @SerialName("experience_years") val experienceYears: Int? = null,
        @SerialName("service_radius_km") val serviceRadiusKm: Int? = null,
        @SerialName("city") val city: String? = null,
        @SerialName("state") val state: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    @Serializable
    data class PendingReport(
        @SerialName("report_id") val reportId: String,
        @SerialName("reporter_user_id") val reporterUserId: String,
        @SerialName("reporter_name") val reporterName: String? = null,
        @SerialName("target_type") val targetType: String,
        @SerialName("target_id") val targetId: String,
        @SerialName("reason") val reason: String,
        @SerialName("notes") val notes: String? = null,
        @SerialName("status") val status: String,
        @SerialName("created_at") val createdAt: String,
    )

    @Serializable
    data class PendingSellerVerification(
        @SerialName("request_id") val requestId: String,
        @SerialName("organization_id") val organizationId: String,
        @SerialName("organization_name") val organizationName: String? = null,
        @SerialName("submitted_by") val submittedBy: String,
        @SerialName("submitter_name") val submitterName: String? = null,
        @SerialName("gst_number") val gstNumber: String,
        @SerialName("trade_licence_url") val tradeLicenceUrl: String,
        @SerialName("submitted_at") val submittedAt: String,
    )

    suspend fun fetchPendingEngineers(): Result<List<PendingEngineer>> = runCatching {
        client.postgrest.rpc(function = "admin_pending_engineers")
            .decodeList<PendingEngineer>()
    }

    suspend fun setEngineerVerification(
        userId: String,
        status: String,
        reason: String?,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_set_engineer_verification",
            parameters = buildJsonObject {
                put("p_user_id", JsonPrimitive(userId))
                put("p_status", JsonPrimitive(status))
                put("p_reason", reason?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
            },
        )
        Unit
    }

    suspend fun fetchPendingSellerVerifications(): Result<List<PendingSellerVerification>> = runCatching {
        client.postgrest.rpc(function = "admin_pending_seller_verifications")
            .decodeList<PendingSellerVerification>()
    }

    suspend fun fetchPendingReports(): Result<List<PendingReport>> = runCatching {
        client.postgrest.rpc(function = "admin_pending_reports")
            .decodeList<PendingReport>()
    }

    suspend fun resolveReport(
        reportId: String,
        status: String,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_resolve_report",
            parameters = buildJsonObject {
                put("p_report_id", JsonPrimitive(reportId))
                put("p_status", JsonPrimitive(status))
            },
        )
        Unit
    }

    suspend fun setOrgVerification(
        orgId: String,
        status: String,
        reason: String?,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_set_org_verification",
            parameters = buildJsonObject {
                put("p_org_id", JsonPrimitive(orgId))
                put("p_status", JsonPrimitive(status))
                put("p_reason", reason?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
            },
        )
        Unit
    }
}
