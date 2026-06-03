package com.equipseva.app.core.data.payouts

enum class PayoutMethodKind { Upi, Bank }
enum class PayoutMethodVerification { Unverified, Verified, Invalid }
enum class PayoutStatus { Queued, Processing, Processed, Failed, Cancelled }

data class EngineerPayoutMethod(
    val id: String,
    val kind: PayoutMethodKind,
    val vpa: String?,
    val vpaHolderName: String?,
    val bankAccountHolder: String?,
    val bankName: String?,
    val ifsc: String?,
    val accountLast4: String?,
    val verificationStatus: PayoutMethodVerification,
) {
    fun displayLine(): String = when (kind) {
        PayoutMethodKind.Upi -> vpa.orEmpty()
        PayoutMethodKind.Bank -> {
            val left = bankName?.takeIf { it.isNotBlank() } ?: "Bank"
            "$left •••• ${accountLast4.orEmpty()}"
        }
    }
}

data class EngineerPayoutRow(
    val id: String,
    val jobNumber: String,
    val amountPaise: Long,
    val status: PayoutStatus,
    val mode: String?,
    val utr: String?,
    val failureReason: String?,
    val destinationLabel: String?,
    val queuedAt: String,
    val processedAt: String?,
)

/**
 * Round 431. Per-job payout status. Returned to BOTH the hospital
 * (who paid the escrow) and the engineer (who is owed) so both sides
 * see the same forensic anchor — anti-disintermediation reinforcement
 * (the engineer was paid through the platform, with a verifiable
 * bank trail).
 */
data class JobPayoutStatus(
    val id: String,
    val amountPaise: Long,
    val status: PayoutStatus,
    val mode: String?,
    val utr: String?,
    val failureReason: String?,
    val destinationLabel: String?,
    val engineerName: String?,
    val queuedAt: String,
    val processedAt: String?,
)
