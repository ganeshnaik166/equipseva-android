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

    @Serializable
    data class RecentPayment(
        @SerialName("order_id") val orderId: String,
        @SerialName("order_number") val orderNumber: String,
        @SerialName("buyer_user_id") val buyerUserId: String,
        @SerialName("buyer_name") val buyerName: String? = null,
        @SerialName("total_amount") val totalAmount: Double,
        @SerialName("payment_status") val paymentStatus: String? = null,
        @SerialName("order_status") val orderStatus: String? = null,
        @SerialName("razorpay_order_id") val razorpayOrderId: String? = null,
        @SerialName("payment_id") val paymentId: String? = null,
        @SerialName("invoice_url") val invoiceUrl: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    @Serializable
    data class IntegrityFlag(
        @SerialName("check_id") val checkId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("user_email") val userEmail: String? = null,
        @SerialName("action") val action: String? = null,
        @SerialName("device_verdict") val deviceVerdict: String? = null,
        @SerialName("app_verdict") val appVerdict: String? = null,
        @SerialName("licensing_verdict") val licensingVerdict: String? = null,
        @SerialName("pass") val pass: Boolean,
        @SerialName("created_at") val createdAt: String? = null,
    )

    @Serializable
    data class UserRow(
        @SerialName("user_id") val userId: String,
        @SerialName("email") val email: String? = null,
        @SerialName("phone") val phone: String? = null,
        @SerialName("full_name") val fullName: String? = null,
        @SerialName("role") val role: String? = null,
        @SerialName("organization_id") val organizationId: String? = null,
        @SerialName("is_active") val isActive: Boolean = true,
        @SerialName("created_at") val createdAt: String? = null,
    )

    @Serializable
    data class DashboardStats(
        @SerialName("pending_kyc") val pendingKyc: Int = 0,
        @SerialName("pending_sellers") val pendingSellers: Int = 0,
        @SerialName("pending_reports") val pendingReports: Int = 0,
        @SerialName("orders_today") val ordersToday: Int = 0,
        @SerialName("integrity_failures_today") val integrityFailuresToday: Int = 0,
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

    suspend fun fetchRecentPayments(limit: Int = 50): Result<List<RecentPayment>> = runCatching {
        client.postgrest.rpc(
            function = "admin_recent_payments",
            parameters = buildJsonObject {
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<RecentPayment>()
    }

    suspend fun fetchIntegrityFlags(limit: Int = 100): Result<List<IntegrityFlag>> = runCatching {
        client.postgrest.rpc(
            function = "admin_integrity_flags",
            parameters = buildJsonObject {
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<IntegrityFlag>()
    }

    suspend fun searchUsers(
        query: String,
        role: String?,
        limit: Int = 50,
        offset: Int = 0,
    ): Result<List<UserRow>> = runCatching {
        client.postgrest.rpc(
            function = "admin_users_search",
            parameters = buildJsonObject {
                put("p_query", JsonPrimitive(query))
                put("p_role", role?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
                put("p_limit", JsonPrimitive(limit))
                put("p_offset", JsonPrimitive(offset))
            },
        ).decodeList<UserRow>()
    }

    suspend fun forceRoleChange(userId: String, newRole: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_force_role_change",
            parameters = buildJsonObject {
                put("p_user_id", JsonPrimitive(userId))
                put("p_new_role", JsonPrimitive(newRole))
            },
        )
        Unit
    }

    suspend fun fetchDashboardStats(): Result<DashboardStats> = runCatching {
        client.postgrest.rpc(function = "admin_dashboard_stats")
            .decodeSingle<DashboardStats>()
    }
}
