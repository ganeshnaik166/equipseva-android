package com.equipseva.app.features.founder

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
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
        @SerialName("certificates") val certificates: kotlinx.serialization.json.JsonElement? = null,
        @SerialName("aadhaar_verified") val aadhaarVerified: Boolean = false,
        @SerialName("created_at") val createdAt: String? = null,
    ) {
        /**
         * Pulls every storage-key path out of the certificates JSONB so the
         * founder UI can ask Storage for a short-lived signed URL per doc.
         * Tolerates the legacy shape (list of objects with type+path) and
         * a flat string list.
         */
        fun docPaths(): List<DocRef> {
            val cert = certificates ?: return emptyList()
            return when (cert) {
                is kotlinx.serialization.json.JsonArray -> cert.mapNotNull { entry ->
                    when (entry) {
                        is kotlinx.serialization.json.JsonObject -> {
                            val path = (entry["path"] as? kotlinx.serialization.json.JsonPrimitive)?.contentOrNull
                            val type = (entry["type"] as? kotlinx.serialization.json.JsonPrimitive)?.contentOrNull
                            if (path.isNullOrBlank()) null else DocRef(type ?: "doc", path)
                        }
                        is kotlinx.serialization.json.JsonPrimitive -> entry.contentOrNull?.takeIf { it.isNotBlank() }
                            ?.let { DocRef("doc", it) }
                        else -> null
                    }
                }
                else -> emptyList()
            }
        }

        data class DocRef(val type: String, val path: String) {
            val displayLabel: String
                get() = when (type.lowercase()) {
                    "aadhaar" -> "Aadhaar"
                    "cert" -> "Certificate"
                    else -> type.replaceFirstChar { it.uppercase() }
                }
        }
    }

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
    data class RecentPaymentsStats(
        @SerialName("window_days") val windowDays: Int,
        @SerialName("total_orders") val totalOrders: Long,
        @SerialName("paid_count") val paidCount: Long,
        @SerialName("failed_count") val failedCount: Long,
        @SerialName("pending_count") val pendingCount: Long,
        @SerialName("refunded_count") val refundedCount: Long,
        @SerialName("gmv_paid_inr") val gmvPaidInr: Double,
        @SerialName("gmv_refunded_inr") val gmvRefundedInr: Double,
        @SerialName("largest_paid_inr") val largestPaidInr: Double,
        @SerialName("last_paid_at") val lastPaidAt: String? = null,
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
    data class PendingBuyerKyc(
        @SerialName("request_id") val requestId: String,
        @SerialName("user_id") val userId: String,
        @SerialName("full_name") val fullName: String,
        @SerialName("email") val email: String? = null,
        @SerialName("phone") val phone: String? = null,
        @SerialName("doc_type") val docType: String,
        @SerialName("doc_url") val docUrl: String,
        @SerialName("gst_number") val gstNumber: String? = null,
        @SerialName("status") val status: String,
        @SerialName("submitted_at") val submittedAt: String,
    )

    @Serializable
    data class CategoryRow(
        @SerialName("key") val key: String,
        @SerialName("display_name") val displayName: String,
        @SerialName("scope") val scope: String,
        @SerialName("sort_order") val sortOrder: Int = 100,
        @SerialName("is_active") val isActive: Boolean = true,
        @SerialName("image_url") val imageUrl: String? = null,
        @SerialName("updated_at") val updatedAt: String? = null,
    )

    @Serializable
    data class DashboardStats(
        @SerialName("pending_kyc") val pendingKyc: Int = 0,
        @SerialName("pending_sellers") val pendingSellers: Int = 0,
        @SerialName("pending_reports") val pendingReports: Int = 0,
        @SerialName("orders_today") val ordersToday: Int = 0,
        @SerialName("integrity_failures_today") val integrityFailuresToday: Int = 0,
        // Round 343 growth metrics. Defaulted to 0 so a client deployed
        // before the server-side migration lands still decodes the row.
        @SerialName("new_signups_today") val newSignupsToday: Int = 0,
        @SerialName("active_repair_jobs") val activeRepairJobs: Int = 0,
        @SerialName("amc_contracts_active") val amcContractsActive: Int = 0,
        @SerialName("amc_contracts_expired") val amcContractsExpired: Int = 0,
        // Round 352 — active contracts ending in the next 30 days. Default
        // 0 so older clients decoding a fresh response still parse.
        @SerialName("amc_contracts_expiring_soon") val amcContractsExpiringSoon: Int = 0,
    )

    @Serializable
    data class EngineerZoneRow(
        val district: String,
        @SerialName("engineer_count") val engineerCount: Int = 0,
        @SerialName("sample_lat") val sampleLat: Double? = null,
        @SerialName("sample_lng") val sampleLng: Double? = null,
    )

    @Serializable
    data class TopEngineerRow(
        @SerialName("engineer_user_id") val engineerUserId: String,
        @SerialName("full_name") val fullName: String,
        @SerialName("jobs_completed") val jobsCompleted: Long,
        @SerialName("revenue_inr") val revenueInr: Double,
        @SerialName("last_completed_at") val lastCompletedAt: String? = null,
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

    suspend fun fetchRecentPayments(limit: Int = 50): Result<List<RecentPayment>> = runCatching {
        client.postgrest.rpc(
            function = "admin_recent_payments",
            parameters = buildJsonObject {
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<RecentPayment>()
    }

    suspend fun fetchRecentPaymentsStats(windowDays: Int = 30): Result<RecentPaymentsStats?> = runCatching {
        client.postgrest.rpc(
            function = "admin_recent_payments_stats",
            parameters = buildJsonObject {
                put("p_days", JsonPrimitive(windowDays))
            },
        ).decodeList<RecentPaymentsStats>().firstOrNull()
    }

    suspend fun fetchTopEngineers(windowDays: Int = 30, limit: Int = 5): Result<List<TopEngineerRow>> = runCatching {
        client.postgrest.rpc(
            function = "admin_top_engineers",
            parameters = buildJsonObject {
                put("p_days", JsonPrimitive(windowDays))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<TopEngineerRow>()
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
        // admin_users_search short-circuits on `p_role IS NULL` (returns
        // every role) — sending JsonPrimitive("") instead falsely
        // narrowed the WHERE to `p.role::text = ''`, so the "All" filter
        // returned zero rows on every install. Send JsonNull when no
        // role is selected (verified on Realme 2026-05-08 e2e QA — Users
        // queue surface showed "No matches" with 50+ real users in DB).
        client.postgrest.rpc(
            function = "admin_users_search",
            parameters = buildJsonObject {
                put("p_query", JsonPrimitive(query))
                put("p_role", role?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
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

    suspend fun fetchEngineersByDistrict(): Result<List<EngineerZoneRow>> = runCatching {
        client.postgrest.rpc(function = "admin_engineers_by_district")
            .decodeList<EngineerZoneRow>()
    }

    suspend fun fetchCategories(): Result<List<CategoryRow>> = runCatching {
        client.postgrest.rpc(function = "admin_categories_list")
            .decodeList<CategoryRow>()
    }

    suspend fun upsertCategory(
        key: String,
        displayName: String,
        scope: String,
        sortOrder: Int,
        isActive: Boolean,
        imageUrl: String? = null,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_categories_upsert",
            parameters = buildJsonObject {
                put("p_key", JsonPrimitive(key))
                put("p_display_name", JsonPrimitive(displayName))
                put("p_scope", JsonPrimitive(scope))
                put("p_sort_order", JsonPrimitive(sortOrder))
                put("p_is_active", JsonPrimitive(isActive))
                put("p_image_url", imageUrl?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            },
        )
        Unit
    }

    suspend fun fetchPendingBuyerKyc(): Result<List<PendingBuyerKyc>> = runCatching {
        client.postgrest.rpc(function = "admin_pending_buyer_kyc")
            .decodeList<PendingBuyerKyc>()
    }

    suspend fun setBuyerKycStatus(
        requestId: String,
        status: String,
        reason: String?,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_set_buyer_kyc_status",
            parameters = buildJsonObject {
                put("p_request_id", JsonPrimitive(requestId))
                put("p_status", JsonPrimitive(status))
                put("p_reason", reason?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            },
        )
        Unit
    }

    // ---------------------------------------------------------------
    // v2.1 PR-D21 — admin ops queues (escrow disputes, AMC escalations,
    // cash-flagged engineers, parts-cost outliers).
    // ---------------------------------------------------------------

    @Serializable
    data class EscrowDispute(
        @SerialName("escrow_id") val escrowId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("engineer_user_id") val engineerUserId: String,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("dispute_opened_at") val disputeOpenedAt: String? = null,
        @SerialName("dispute_reason") val disputeReason: String? = null,
        @SerialName("scheduled_release_at") val scheduledReleaseAt: String? = null,
    )

    @Serializable
    data class AmcEscalation(
        @SerialName("escalation_id") val escalationId: String,
        @SerialName("amc_contract_id") val amcContractId: String,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("visit_id") val visitId: String? = null,
        @SerialName("visit_number") val visitNumber: Int? = null,
        @SerialName("reason") val reason: String,
        @SerialName("notes") val notes: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    @Serializable
    data class CashSuspendedEngineer(
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("full_name") val fullName: String? = null,
        @SerialName("cash_auto_suspended_at") val suspendedAt: String? = null,
        @SerialName("cash_auto_suspension_reason") val reason: String? = null,
        @SerialName("flag_count_90d") val flagCount90d: Int = 0,
    )

    @Serializable
    data class PartsCostOutlier(
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("engineer_id") val engineerId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("parts_cost") val partsCost: Double,
        @SerialName("category_avg_parts") val categoryAvgParts: Double,
        @SerialName("ratio") val ratio: Double,
        @SerialName("completed_at") val completedAt: String? = null,
    )

    suspend fun fetchOpenEscrowDisputes(): Result<List<EscrowDispute>> = runCatching {
        client.postgrest.rpc(function = "admin_list_open_escrow_disputes")
            .decodeList<EscrowDispute>()
    }

    @Serializable
    data class ResolvedDispute(
        @SerialName("escrow_id") val escrowId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("engineer_user_id") val engineerUserId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("outcome") val outcome: String,
        @SerialName("resolved_at") val resolvedAt: String? = null,
        @SerialName("resolved_by") val resolvedBy: String? = null,
        @SerialName("resolved_by_name") val resolvedByName: String? = null,
        @SerialName("resolution_note") val resolutionNote: String? = null,
        @SerialName("dispute_reason") val disputeReason: String? = null,
        @SerialName("engineer_response") val engineerResponse: String? = null,
    )

    suspend fun fetchRecentResolvedDisputes(): Result<List<ResolvedDispute>> = runCatching {
        client.postgrest.rpc(function = "admin_list_recent_resolved_disputes")
            .decodeList<ResolvedDispute>()
    }

    @Serializable
    data class SpotAuditResponseRow(
        @SerialName("response_id") val responseId: String,
        @SerialName("invitation_id") val invitationId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("engineer_id") val engineerId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("rating") val rating: Int,
        @SerialName("feedback") val feedback: String? = null,
        @SerialName("responded_at") val respondedAt: String? = null,
    )

    suspend fun fetchRecentSpotAudits(): Result<List<SpotAuditResponseRow>> = runCatching {
        client.postgrest.rpc(function = "admin_list_recent_spot_audits")
            .decodeList<SpotAuditResponseRow>()
    }

    suspend fun resolveEscrowDispute(
        escrowId: String,
        outcome: String, // "release" or "refund"
        note: String? = null,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_resolve_escrow_dispute",
            parameters = buildJsonObject {
                put("p_escrow_id", JsonPrimitive(escrowId))
                put("p_outcome", JsonPrimitive(outcome))
                put("p_note", note?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            },
        )
        Unit
    }

    suspend fun fetchOpenAmcEscalations(): Result<List<AmcEscalation>> = runCatching {
        client.postgrest.rpc(function = "admin_list_open_amc_escalations")
            .decodeList<AmcEscalation>()
    }

    suspend fun resolveAmcEscalation(
        escalationId: String,
        notes: String?,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "admin_resolve_amc_escalation",
            parameters = buildJsonObject {
                put("p_escalation_id", JsonPrimitive(escalationId))
                put("p_notes", notes?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            },
        )
        Unit
    }

    suspend fun fetchCashSuspendedEngineers(): Result<List<CashSuspendedEngineer>> = runCatching {
        client.postgrest.rpc(function = "admin_list_cash_suspended_engineers")
            .decodeList<CashSuspendedEngineer>()
    }

    suspend fun clearCashAutoSuspension(
        engineerId: String,
        note: String?,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "clear_cash_auto_suspension",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
                put("p_note", note?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            },
        )
        Unit
    }

    @Serializable
    data class AmcEscalationDetail(
        @SerialName("escalation_id") val escalationId: String,
        @SerialName("amc_contract_id") val amcContractId: String,
        @SerialName("visit_id") val visitId: String? = null,
        @SerialName("reason") val reason: String,
        @SerialName("notes") val notes: String? = null,
        @SerialName("resolved_at") val resolvedAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("contract_status") val contractStatus: String? = null,
        @SerialName("visit_frequency") val visitFrequency: String? = null,
        @SerialName("monthly_fee_rupees") val monthlyFeeRupees: Double? = null,
        @SerialName("next_visit_at") val nextVisitAt: String? = null,
        @SerialName("contract_end_date") val contractEndDate: String? = null,
        @SerialName("visit_number") val visitNumber: Int? = null,
        @SerialName("visit_status") val visitStatus: String? = null,
        @SerialName("visit_scheduled_date") val visitScheduledDate: String? = null,
        @SerialName("visit_equipment_type") val visitEquipmentType: String? = null,
    )

    suspend fun fetchAmcEscalationDetail(escalationId: String): Result<AmcEscalationDetail?> = runCatching {
        client.postgrest.rpc(
            function = "admin_amc_escalation_detail",
            parameters = buildJsonObject {
                put("p_escalation_id", JsonPrimitive(escalationId))
            },
        ).decodeList<AmcEscalationDetail>().firstOrNull()
    }

    @Serializable
    data class EscrowEventRow(
        @SerialName("event_id") val eventId: String,
        @SerialName("event_kind") val eventKind: String,
        @SerialName("occurred_at") val occurredAt: String? = null,
        @SerialName("actor_user_id") val actorUserId: String? = null,
        @SerialName("actor_name") val actorName: String? = null,
        @SerialName("payload") val payload: kotlinx.serialization.json.JsonElement? = null,
    )

    @Serializable
    data class DisputePartyTrackRecord(
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_disputes_filed") val hospitalDisputesFiled: Int = 0,
        @SerialName("hospital_disputes_won") val hospitalDisputesWon: Int = 0,
        @SerialName("hospital_disputes_lost") val hospitalDisputesLost: Int = 0,
        @SerialName("hospital_disputes_open") val hospitalDisputesOpen: Int = 0,
        @SerialName("engineer_user_id") val engineerUserId: String? = null,
        @SerialName("engineer_disputes_recv") val engineerDisputesRecv: Int = 0,
        @SerialName("engineer_disputes_won") val engineerDisputesWon: Int = 0,
        @SerialName("engineer_disputes_lost") val engineerDisputesLost: Int = 0,
        @SerialName("engineer_disputes_open") val engineerDisputesOpen: Int = 0,
    )

    suspend fun fetchDisputePartyTrackRecord(escrowId: String): Result<DisputePartyTrackRecord?> = runCatching {
        client.postgrest.rpc(
            function = "admin_dispute_party_track_record",
            parameters = buildJsonObject {
                put("p_escrow_id", JsonPrimitive(escrowId))
            },
        ).decodeList<DisputePartyTrackRecord>().firstOrNull()
    }

    suspend fun fetchEscrowEventTimeline(escrowId: String): Result<List<EscrowEventRow>> = runCatching {
        client.postgrest.rpc(
            function = "admin_escrow_event_timeline",
            parameters = buildJsonObject {
                put("p_escrow_id", JsonPrimitive(escrowId))
            },
        ).decodeList<EscrowEventRow>()
    }

    @Serializable
    data class CashFlagHistoryRow(
        @SerialName("response_id") val responseId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("response") val response: String,
        @SerialName("responded_at") val respondedAt: String? = null,
        @SerialName("completed_at") val completedAt: String? = null,
    )

    suspend fun fetchEngineerCashFlagHistory(engineerId: String): Result<List<CashFlagHistoryRow>> = runCatching {
        client.postgrest.rpc(
            function = "admin_engineer_cash_flag_history",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
            },
        ).decodeList<CashFlagHistoryRow>()
    }

    suspend fun fetchPartsCostOutliers(): Result<List<PartsCostOutlier>> = runCatching {
        // Pass no parameters — let the RPC's SQL defaults (window=90,
        // multiplier=5.0) apply. supabase-kt's JsonPrimitive(Double=5.0)
        // gets serialized as JSON `5` once the value is integral, which
        // breaks PostgREST's (int, numeric) overload resolution and fails
        // the call with a 404 "no function matches". UI controls for
        // tuning the window / multiplier can land later.
        client.postgrest.rpc(function = "list_parts_cost_outliers")
            .decodeList<PartsCostOutlier>()
    }
}
