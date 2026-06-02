package com.equipseva.app.core.data.payouts

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

interface EngineerPayoutRepository {

    /** Read current default destination + VPA verification status. */
    suspend fun fetchCurrent(): Result<EngineerPayoutMethod?>

    /** Save a UPI VPA as the engineer's default destination. */
    suspend fun setUpi(vpa: String, holderName: String?): Result<Unit>

    /** Save bank account fields as the engineer's default destination. */
    suspend fun setBank(
        accountHolder: String,
        accountNumber: String,
        ifsc: String,
        bankName: String?,
    ): Result<Unit>

    /** List the engineer's payouts (enriched with job number + masked destination). */
    suspend fun listPayouts(limit: Int = 50): Result<List<EngineerPayoutRow>>
}

@Singleton
class SupabaseEngineerPayoutRepository @Inject constructor(
    private val client: SupabaseClient,
) : EngineerPayoutRepository {

    override suspend fun fetchCurrent(): Result<EngineerPayoutMethod?> = runCatching {
        client.postgrest
            .from(TABLE_METHODS)
            .select {
                filter { eq("is_default", true) }
                limit(1)
            }
            .decodeList<EngineerPayoutMethodDto>()
            .firstOrNull()
            ?.toDomain()
    }

    override suspend fun setUpi(vpa: String, holderName: String?): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "set_engineer_payout_method",
            parameters = buildJsonObject {
                put("p_kind", JsonPrimitive("upi"))
                put("p_vpa", JsonPrimitive(vpa.trim()))
                if (!holderName.isNullOrBlank()) {
                    put("p_vpa_holder_name", JsonPrimitive(holderName.trim()))
                }
            },
        )
        Unit
    }

    override suspend fun setBank(
        accountHolder: String,
        accountNumber: String,
        ifsc: String,
        bankName: String?,
    ): Result<Unit> = runCatching {
        // We do NOT have a client-side encryption rail wired up yet. The
        // RPC accepts an "encrypted" blob today purely so we can keep
        // the schema future-proof when the encrypt-at-rest pipeline
        // lands; for v1 we send the same value to both fields so the
        // app+server contract holds. The bank_accounts.account_number_
        // encrypted column has been unused since shipped; treating it
        // as deferred infra (T+next release).
        val cleaned = accountNumber.filter { it.isDigit() }
        val last4 = cleaned.takeLast(4)
        client.postgrest.rpc(
            function = "set_engineer_payout_method",
            parameters = buildJsonObject {
                put("p_kind", JsonPrimitive("bank"))
                put("p_bank_account_holder", JsonPrimitive(accountHolder.trim()))
                put("p_ifsc", JsonPrimitive(ifsc.trim().uppercase()))
                put("p_account_number_encrypted", JsonPrimitive(cleaned))
                put("p_account_number_last4", JsonPrimitive(last4))
                if (!bankName.isNullOrBlank()) {
                    put("p_bank_name", JsonPrimitive(bankName.trim()))
                }
            },
        )
        Unit
    }

    override suspend fun listPayouts(limit: Int): Result<List<EngineerPayoutRow>> = runCatching {
        client.postgrest
            .rpc(
                function = "list_engineer_payouts",
                parameters = buildJsonObject { put("p_limit", JsonPrimitive(limit)) },
            )
            .decodeList<EngineerPayoutRowDto>()
            .map { it.toDomain() }
    }

    private companion object {
        const val TABLE_METHODS = "engineer_payout_methods"
    }
}

/* -------------- DTOs (kept internal to the data layer) -------------- */

@Serializable
internal data class EngineerPayoutMethodDto(
    val id: String,
    val kind: String,
    val vpa: String? = null,
    val vpa_holder_name: String? = null,
    val bank_account_holder: String? = null,
    val bank_name: String? = null,
    val ifsc: String? = null,
    val account_number_last4: String? = null,
    val status: String,
    val is_default: Boolean,
) {
    fun toDomain() = EngineerPayoutMethod(
        id = id,
        kind = when (kind) {
            "upi" -> PayoutMethodKind.Upi
            "bank" -> PayoutMethodKind.Bank
            else -> PayoutMethodKind.Upi
        },
        vpa = vpa,
        vpaHolderName = vpa_holder_name,
        bankAccountHolder = bank_account_holder,
        bankName = bank_name,
        ifsc = ifsc,
        accountLast4 = account_number_last4,
        verificationStatus = when (status) {
            "verified" -> PayoutMethodVerification.Verified
            "invalid" -> PayoutMethodVerification.Invalid
            else -> PayoutMethodVerification.Unverified
        },
    )
}

@Serializable
internal data class EngineerPayoutRowDto(
    val id: String,
    val repair_job_id: String,
    val job_number: String,
    val amount_paise: Long,
    val status: String,
    val mode: String? = null,
    val utr: String? = null,
    val failure_reason: String? = null,
    val destination_label: String? = null,
    val queued_at: String,
    val processed_at: String? = null,
) {
    fun toDomain() = EngineerPayoutRow(
        id = id,
        jobNumber = job_number,
        amountPaise = amount_paise,
        status = when (status) {
            "queued" -> PayoutStatus.Queued
            "processing" -> PayoutStatus.Processing
            "processed" -> PayoutStatus.Processed
            "failed" -> PayoutStatus.Failed
            "cancelled" -> PayoutStatus.Cancelled
            else -> PayoutStatus.Queued
        },
        mode = mode,
        utr = utr,
        failureReason = failure_reason,
        destinationLabel = destination_label,
        queuedAt = queued_at,
        processedAt = processed_at,
    )
}
