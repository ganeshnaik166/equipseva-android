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
 * (see SupabaseVirtualCallRepository for the full reasoning) — we want
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
        @SerialName("id") val id: String,
        @SerialName("primary_engineer_id") val primaryEngineerId: String,
        @SerialName("primary_engineer_name") val primaryEngineerName: String,
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
        raw.trim().trim('"').toDoubleOrNull() ?: 0.0
    }

    suspend fun listSlaBreaches(contractId: String): Result<List<AmcSlaBreach>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_sla_breaches_for_contract",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
            },
        ).decodeList<AmcSlaBreach>()
    }

    suspend fun listRotation(contractId: String): Result<List<AmcRotationRow>> = runCatching {
        supabase.postgrest.rpc(
            function = "list_amc_rotation",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
            },
        ).decodeList<AmcRotationRow>()
    }

    suspend fun addFallbackEngineer(
        contractId: String,
        engineerId: String,
        priority: Int? = null,
    ): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "add_amc_fallback_engineer",
            parameters = buildJsonObject {
                put("p_contract_id", JsonPrimitive(contractId))
                put("p_engineer_id", JsonPrimitive(engineerId))
                put("p_priority", priority?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        )
        Unit
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
            // SupabaseVirtualCallRepository so non-2xx responses surface
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
