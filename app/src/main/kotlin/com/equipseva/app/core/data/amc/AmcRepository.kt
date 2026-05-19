package com.equipseva.app.core.data.amc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject

/**
 * v2.1 PR-C6 — Android repository fronting the AMC (Annual Maintenance
 * Contract) backend. Mirrors the existing supabase-kt 3.x pattern:
 * [postgrest].rpc(...) for SECURITY DEFINER RPCs, [functions].invoke(...)
 * for edge functions that touch Razorpay or other side-effects.
 *
 * Edge-function calls are wrapped in try/catch on RestException because
 * supabase-kt 3.x's Functions plugin auto-throws on any non-2xx response
 * (see VirtualCallRepository for the full reasoning) — we want
 * the typed body parsing path to run, not bubble a generic toast.
 */
@Singleton
class AmcRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    // -------------------------------------------------------------------
    //  Data shapes
    //
    //  Field names use @SerialName matching the underlying RPC return
    //  shape so kotlinx-serialization's strict default works without a
    //  custom decoder.
    // -------------------------------------------------------------------

    /** Row returned by `list_amc_contracts_for_hospital`. */
    @Serializable
    data class HospitalContract(
        val id: String,
        @SerialName("primary_engineer_id") val primaryEngineerId: String,
        @SerialName("primary_engineer_name") val primaryEngineerName: String,
        val status: String,
        @SerialName("visit_frequency") val visitFrequency: String,
        @SerialName("visits_per_year") val visitsPerYear: Int,
        @SerialName("monthly_fee_rupees") val monthlyFeeRupees: Double,
        @SerialName("start_date") val startDate: String,
        @SerialName("end_date") val endDate: String,
        @SerialName("scope_text") val scopeText: String? = null,
        @SerialName("equipment_categories") val equipmentCategories: List<String> = emptyList(),
        @SerialName("next_visit_at") val nextVisitAt: String? = null,
        @SerialName("visits_completed") val visitsCompleted: Int = 0,
        @SerialName("visits_scheduled") val visitsScheduled: Int = 0,
        @SerialName("auto_renew") val autoRenew: Boolean = true,
        @SerialName("created_at") val createdAt: String,
    )

    /** Row returned by `list_amc_contracts_for_engineer`. */
    @Serializable
    data class EngineerContract(
        @SerialName("id") val id: String,
        @SerialName("hospital_user_id") val hospitalUserId: String,
        @SerialName("hospital_name") val hospitalName: String,
        @SerialName("status") val status: String,
        @SerialName("visit_frequency") val visitFrequency: String,
        @SerialName("visits_per_year") val visitsPerYear: Int,
        @SerialName("monthly_fee_rupees") val monthlyFeeRupees: Double,
        @SerialName("start_date") val startDate: String,
        @SerialName("end_date") val endDate: String,
        @SerialName("scope_text") val scopeText: String? = null,
        @SerialName("equipment_categories") val equipmentCategories: List<String> = emptyList(),
        @SerialName("next_visit_at") val nextVisitAt: String? = null,
        @SerialName("visits_completed") val visitsCompleted: Int = 0,
        @SerialName("visits_scheduled") val visitsScheduled: Int = 0,
        @SerialName("is_primary") val isPrimary: Boolean = false,
    )

    /** Row returned by `list_amc_rotation`. */
    @Serializable
    data class AmcRotationRow(
        @SerialName("rotation_id") val rotationId: String,
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("engineer_name") val engineerName: String,
        @SerialName("engineer_city") val engineerCity: String? = null,
        @SerialName("priority") val priority: Int,
        @SerialName("is_primary") val isPrimary: Boolean,
        @SerialName("active") val active: Boolean,
        @SerialName("is_available") val isAvailable: Boolean = false,
    )

    /** Row returned by `engineer_my_amc_visits` (PR-D33). */
    @Serializable
    data class EngineerAmcVisit(
        @SerialName("visit_id") val visitId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("amc_contract_id") val amcContractId: String,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("visit_number") val visitNumber: Int? = null,
        @SerialName("status") val status: String,
        @SerialName("scheduled_date") val scheduledDate: String? = null,
        @SerialName("completed_at") val completedAt: String? = null,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("breach_count") val breachCount: Int = 0,
    )

    /** Row returned by `list_amc_sla_breaches_for_contract`. */
    @Serializable
    data class AmcSlaBreach(
        @SerialName("breach_id") val breachId: String,
        @SerialName("visit_id") val visitId: String? = null,
        @SerialName("visit_code") val visitCode: String? = null,
        @SerialName("breach_type") val breachType: String,
        @SerialName("severity") val severity: String,
        @SerialName("expected_within_hours") val expectedWithinHours: Int,
        @SerialName("actual_hours") val actualHours: Double? = null,
        @SerialName("credit_issued_rupees") val creditIssuedRupees: Double = 0.0,
        @SerialName("detected_at") val detectedAt: String,
        @SerialName("resolved_at") val resolvedAt: String? = null,
    )

    /** Response body of `create-amc-payment-order` edge fn. */
    @Serializable
    data class CreateAmcPaymentOrderResponse(
        @SerialName("ok") val ok: Boolean = true,
        @SerialName("payment_order_id") val paymentOrderId: String,
        @SerialName("razorpay_order_id") val razorpayOrderId: String,
        @SerialName("amount_paise") val amountPaise: Long,
        @SerialName("currency") val currency: String,
        @SerialName("key_id") val keyId: String,
    )

    /** Response body of `verify-amc-payment` edge fn. */
    @Serializable
    data class VerifyAmcPaymentResponse(
        @SerialName("ok") val ok: Boolean = true,
        @SerialName("payment_order_id") val paymentOrderId: String,
        @SerialName("ledger_id") val ledgerId: String? = null,
        @SerialName("balance_after") val balanceAfter: Double? = null,
        @SerialName("contract_status") val contractStatus: String? = null,
        @SerialName("idempotent") val idempotent: Boolean = false,
    )

    /** Typed error envelope returned by both edge fns on non-2xx. */
    @Serializable
    data class EdgeFnError(
        @SerialName("ok") val ok: Boolean = false,
        @SerialName("code") val code: String? = null,
        @SerialName("message") val message: String? = null,
    )

    // -------------------------------------------------------------------
    //  RPC wrappers
    // -------------------------------------------------------------------

    suspend fun listForHospital(): Result<List<HospitalContract>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_contracts_for_hospital",
        ).decodeList<HospitalContract>()
    }

    suspend fun listForEngineer(): Result<List<EngineerContract>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_contracts_for_engineer",
        ).decodeList<EngineerContract>()
    }

    suspend fun cancelContract(contractId: String, reason: String?): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "cancel_amc_contract",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
                put("p_reason", reason?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        )
        Unit
    }

    suspend fun getPoolBalance(contractId: String): Result<Double> = runCatching {
        // RPC returns a scalar numeric; supabase-kt's decodeAs<T> handles it.
        val raw = supabase.postgrest.rpc(
            function = "get_amc_pool_balance",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
            },
        ).data
        // Body is a bare JSON number (e.g. "1234.50"). Trim quotes if any
        // (defensive — supabase-kt sometimes wraps numerics) then parse.
        // Throw on parse failure so the VM surfaces an error banner —
        // silently coercing to ₹0.0 hid backend errors as a fake "empty
        // pool", indistinguishable from a real zero balance.
        raw.trim().trim('"').toDoubleOrNull()
            ?: error("Couldn't read pool balance (server returned: ${raw.take(40)})")
    }

    suspend fun listSlaBreaches(contractId: String): Result<List<AmcSlaBreach>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_sla_breaches_for_contract",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
            },
        ).decodeList<AmcSlaBreach>()
    }

    suspend fun listMyAmcVisits(): Result<List<EngineerAmcVisit>> = runCatching {
        supabase.postgrest.rpc(function = "engineer_my_amc_visits")
            .decodeList<EngineerAmcVisit>()
    }

    /** Row returned by `engineer_my_amc_earnings` (Round 234 PR-#619). */
    @Serializable
    data class EngineerAmcEarning(
        @SerialName("visit_id") val visitId: String,
        @SerialName("visit_completed_at") val visitCompletedAt: String? = null,
        @SerialName("amc_contract_id") val amcContractId: String? = null,
        @SerialName("per_visit_cost_rupees") val perVisitCostRupees: Double = 0.0,
        @SerialName("engineer_payout_rupees") val engineerPayoutRupees: Double = 0.0,
        @SerialName("platform_take_rupees") val platformTakeRupees: Double = 0.0,
    )

    /**
     * v2.1 Round-234 — engineer self-view of AMC visit payouts. 85%
     * of the per-visit cost goes to the engineer; remaining 15% is
     * the platform take. RLS is enforced inside the RPC via
     * `engineers.user_id = auth.uid()`.
     */
    suspend fun listMyAmcEarnings(): Result<List<EngineerAmcEarning>> = runCatching {
        supabase.postgrest.rpc(function = "engineer_my_amc_earnings")
            .decodeList<EngineerAmcEarning>()
    }

    @Serializable
    private data class AmcPaymentOrderStatusRow(@SerialName("status") val status: String? = null)

    /**
     * Round 234 — direct status read for the process-death reconciler.
     * RLS gates: only the hospital that owns the contract can see the
     * order. Returns null when the row is invisible / deleted (which
     * the reconciler treats as a terminal "drop the marker").
     */
    suspend fun fetchAmcPaymentOrderStatus(paymentOrderId: String): Result<String?> = runCatching {
        supabase.postgrest.from("amc_payment_orders")
            .select(columns = io.github.jan.supabase.postgrest.query.Columns.list("status")) {
                filter { eq("id", paymentOrderId) }
                limit(1)
            }
            .decodeList<AmcPaymentOrderStatusRow>()
            .firstOrNull()
            ?.status
    }

    @Serializable
    data class HospitalSlaCreditSummary(
        @SerialName("total_credit_rupees") val totalCreditRupees: Double = 0.0,
        @SerialName("breach_count") val breachCount: Int = 0,
        @SerialName("most_recent_at") val mostRecentAt: String? = null,
    )

    /**
     * v2.1 PR-D34 — aggregated AMC SLA credits issued to the caller
     * (hospital) in the trailing window. Used by the hospital home
     * card; surface only when totalCreditRupees > 0.
     */
    suspend fun hospitalRecentAmcSlaCredits(): Result<HospitalSlaCreditSummary> = runCatching {
        supabase.postgrest.rpc(function = "hospital_recent_amc_sla_credits")
            .decodeList<HospitalSlaCreditSummary>()
            .firstOrNull() ?: HospitalSlaCreditSummary()
    }

    suspend fun listRotation(contractId: String): Result<List<AmcRotationRow>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_rotation",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
            },
        ).decodeList<AmcRotationRow>()
    }

    suspend fun removeFallbackEngineer(
        contractId: String,
        engineerId: String,
    ): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "remove_amc_fallback_engineer",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
                put("p_engineer_id", JsonPrimitive(engineerId))
            },
        )
        Unit
    }

    @Serializable
    data class PoolLedgerRow(
        @SerialName("id") val id: String,
        @SerialName("ledger_kind") val ledgerKind: String,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("balance_after") val balanceAfter: Double,
        @SerialName("source_payment_order_id") val sourcePaymentOrderId: String? = null,
        @SerialName("source_visit_id") val sourceVisitId: String? = null,
        @SerialName("source_breach_id") val sourceBreachId: String? = null,
        @SerialName("description") val description: String? = null,
        @SerialName("created_at") val createdAtIso: String? = null,
    )

    suspend fun listPoolLedger(
        contractId: String,
        limit: Int = 50,
    ): Result<List<PoolLedgerRow>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_pool_ledger",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<PoolLedgerRow>()
    }

    @Serializable
    data class AmcVisitRow(
        @SerialName("id") val id: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("status") val status: String,
        @SerialName("amc_visit_number") val amcVisitNumber: Int? = null,
        @SerialName("scheduled_date") val scheduledDate: String? = null,
        @SerialName("scheduled_time_slot") val scheduledTimeSlot: String? = null,
        @SerialName("engineer_id") val engineerId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("created_at") val createdAtIso: String? = null,
        @SerialName("completed_at") val completedAtIso: String? = null,
        @SerialName("hospital_rating") val hospitalRating: Int? = null,
    )

    suspend fun listVisits(
        contractId: String,
        limit: Int = 50,
    ): Result<List<AmcVisitRow>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_visits_for_contract",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<AmcVisitRow>()
    }


    /**
     * Calls `create_amc_contract` RPC. Returns the new contract uuid.
     * `fallbackEngineerIds` may be empty.
     */
    suspend fun createContract(
        primaryEngineerId: String,
        visitFrequency: String,
        visitsPerYear: Int,
        monthlyFeeRupees: Double,
        startDate: String,
        endDate: String,
        equipmentCategories: List<String>,
        scopeText: String?,
        responseTimeEmergencyHours: Int,
        responseTimeStandardHours: Int,
        autoRenew: Boolean,
        renewalTermMonths: Int,
        fallbackEngineerIds: List<String>,
    ): Result<String> = runCatching {
        val raw = supabase.postgrest.rpc(
            function = "create_amc_contract",
            parameters = buildJsonObject {
                put("p_primary_engineer_id", JsonPrimitive(primaryEngineerId))
                put("p_visit_frequency", JsonPrimitive(visitFrequency))
                put("p_visits_per_year", JsonPrimitive(visitsPerYear))
                put("p_monthly_fee_rupees", JsonPrimitive(monthlyFeeRupees))
                put("p_start_date", JsonPrimitive(startDate))
                put("p_end_date", JsonPrimitive(endDate))
                put("p_equipment_categories", buildJsonArray {
                    equipmentCategories.forEach { add(it) }
                })
                put("p_scope_text", scopeText?.let { JsonPrimitive(it) } ?: JsonNull)
                put(
                    "p_response_time_emergency_hours",
                    JsonPrimitive(responseTimeEmergencyHours),
                )
                put(
                    "p_response_time_standard_hours",
                    JsonPrimitive(responseTimeStandardHours),
                )
                put("p_auto_renew", JsonPrimitive(autoRenew))
                put("p_renewal_term_months", JsonPrimitive(renewalTermMonths))
                put("p_fallback_engineer_ids", buildJsonArray {
                    fallbackEngineerIds.forEach { add(it) }
                })
            },
        ).data
        // Scalar uuid response — strip JSON quotes.
        raw.trim().trim('"')
    }

    // -------------------------------------------------------------------
    //  Edge-function wrappers
    // -------------------------------------------------------------------

    /**
     * Calls `create-amc-payment-order` to bind an AMC top-up to a fresh
     * Razorpay order. Caller passes [months] (1..36); server computes
     * amount = monthly_fee * months. Returns the Razorpay key + order
     * id needed to launch the Standard Checkout activity.
     */
    suspend fun createPaymentOrder(
        amcContractId: String,
        months: Int,
    ): Result<CreateAmcPaymentOrderResponse> = runCatching {
        val res = try {
            supabase.functions.invoke(
                function = "create-amc-payment-order",
                body = buildJsonObject {
                    put("amc_contract_id", JsonPrimitive(amcContractId))
                    put("months", JsonPrimitive(months))
                },
            )
        } catch (rest: RestException) {
            // Mirror the typed-error mapping pattern from
            // VirtualCallRepository so non-2xx responses surface
            // a useful message instead of a generic toast.
            val parsed = parseRestExceptionBody(rest)
            error(parsed?.message ?: rest.description ?: "Couldn't create payment order")
        }
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            val parsed = runCatching { JSON.decodeFromString(EdgeFnError.serializer(), text) }
                .getOrNull()
            error(parsed?.message ?: "Couldn't create payment order (HTTP ${res.status.value})")
        }
        JSON.decodeFromString(CreateAmcPaymentOrderResponse.serializer(), text)
    }

    /**
     * Calls `verify-amc-payment` after the Razorpay Standard Checkout
     * SDK returns a successful result. Backend re-validates the HMAC,
     * marks the order paid, applies the credit to the pool, and
     * returns the freshly snapshotted balance + (possibly resumed)
     * contract status.
     */
    suspend fun verifyPayment(
        paymentOrderId: String,
        razorpayOrderId: String,
        razorpayPaymentId: String,
        razorpaySignature: String,
    ): Result<VerifyAmcPaymentResponse> = runCatching {
        val res = try {
            supabase.functions.invoke(
                function = "verify-amc-payment",
                body = buildJsonObject {
                    put("payment_order_id", JsonPrimitive(paymentOrderId))
                    put("razorpay_order_id", JsonPrimitive(razorpayOrderId))
                    put("razorpay_payment_id", JsonPrimitive(razorpayPaymentId))
                    put("razorpay_signature", JsonPrimitive(razorpaySignature))
                },
            )
        } catch (rest: RestException) {
            val parsed = parseRestExceptionBody(rest)
            error(parsed?.message ?: rest.description ?: "Payment verification failed")
        }
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            val parsed = runCatching { JSON.decodeFromString(EdgeFnError.serializer(), text) }
                .getOrNull()
            error(parsed?.message ?: "Payment verification failed (HTTP ${res.status.value})")
        }
        JSON.decodeFromString(VerifyAmcPaymentResponse.serializer(), text)
    }

    // =====================================================================
    //  Round 419 — AMC auto-charge (subscriptions) read + setup + cancel.
    //  Phase 3 of the auto-charge feature: thin RPC wrappers. The
    //  forthcoming Razorpay edge fn (phase 5) will call back through
    //  SECDEF webhook RPCs added in r418.
    // =====================================================================

    /** One row from `get_amc_subscription_for_contract`. */
    @Serializable
    data class SubscriptionRow(
        val id: String,
        val status: String,
        @SerialName("razorpay_subscription_id") val razorpaySubscriptionId: String? = null,
        @SerialName("current_period_start") val currentPeriodStart: String? = null,
        @SerialName("current_period_end") val currentPeriodEnd: String? = null,
        @SerialName("next_charge_at") val nextChargeAt: String? = null,
        @SerialName("last_charged_at") val lastChargedAt: String? = null,
        @SerialName("total_charges_succeeded") val totalChargesSucceeded: Int = 0,
        @SerialName("total_charges_failed") val totalChargesFailed: Int = 0,
        @SerialName("mandate_summary") val mandateSummary: String? = null,
        @SerialName("last_failure_reason") val lastFailureReason: String? = null,
        @SerialName("last_failure_at") val lastFailureAt: String? = null,
    )

    /** One row from `list_amc_subscription_charges_for_contract`. */
    @Serializable
    data class SubscriptionChargeRow(
        val id: String,
        @SerialName("razorpay_payment_id") val razorpayPaymentId: String? = null,
        @SerialName("amount_rupees") val amountRupees: Double,
        val status: String, // attempted|succeeded|failed|refunded
        @SerialName("period_start") val periodStart: String,
        @SerialName("period_end") val periodEnd: String,
        @SerialName("failure_reason") val failureReason: String? = null,
        @SerialName("attempted_at") val attemptedAt: String,
        @SerialName("settled_at") val settledAt: String? = null,
    )

    /**
     * Read the most-recent subscription row for the given contract. Returns
     * null when no subscription has been set up (cold-state) or when the
     * caller isn't authorized to see it (RLS).
     */
    suspend fun fetchSubscription(amcContractId: String): Result<SubscriptionRow?> = runCatching {
        supabase.postgrest.rpc(
            function = "get_amc_subscription_for_contract",
            parameters = buildJsonObject {
                put("p_amc_contract_id", JsonPrimitive(amcContractId))
            },
        ).decodeList<SubscriptionRow>().firstOrNull()
    }

    /**
     * Idempotent setup-request. Server enforces hospital-only + active/paused
     * contract status. Returns the local subscription row id; the actual
     * Razorpay subscription creation happens in a follow-up edge-fn call.
     */
    suspend fun requestSubscriptionSetup(amcContractId: String): Result<String> = runCatching {
        val res = supabase.postgrest.rpc(
            function = "request_amc_subscription_setup",
            parameters = buildJsonObject {
                put("p_amc_contract_id", JsonPrimitive(amcContractId))
            },
        )
        // Server returns the uuid as a JSON scalar — supabase-kt wraps it
        // in the response body; decode as String directly.
        res.data.trim('"')
    }

    /** Cancel a subscription. Hospital / admin / founder allowed. Idempotent on terminal status. */
    suspend fun cancelSubscription(subscriptionId: String): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "cancel_amc_subscription",
            parameters = buildJsonObject {
                put("p_subscription_id", JsonPrimitive(subscriptionId))
            },
        )
        Unit
    }

    /** Last N charge attempts for the contract. Default 50, server clamps [1,200]. */
    suspend fun listSubscriptionCharges(
        amcContractId: String,
        limit: Int = 50,
    ): Result<List<SubscriptionChargeRow>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_subscription_charges_for_contract",
            parameters = buildJsonObject {
                put("p_amc_contract_id", JsonPrimitive(amcContractId))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<SubscriptionChargeRow>()
    }

    private fun parseRestExceptionBody(rest: RestException): EdgeFnError? {
        for (raw in listOfNotNull(rest.error, rest.description)) {
            if (raw.isBlank()) continue
            val parsed = runCatching { JSON.decodeFromString(EdgeFnError.serializer(), raw) }
                .getOrNull()
            if (parsed?.message != null || parsed?.code != null) return parsed
        }
        return EdgeFnError(message = rest.description?.takeIf { it.isNotBlank() })
    }

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
