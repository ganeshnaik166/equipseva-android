package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Hospital self-view of "first job free" promo eligibility (round 504):
 * whether the caller qualifies, a machine reason when not, and the rupee cap
 * on the subsidy. first_job_free_eligible() is auth.uid()-scoped server-side.
 * Read-only; single row.
 */
@Singleton
class FirstJobFreeRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class FirstJobFree(
        @SerialName("eligible") val eligible: Boolean = false,
        // null when eligible; else already_redeemed | not_first_time_user |
        // account_under_review.
        @SerialName("reason_if_not") val reasonIfNot: String? = null,
        @SerialName("cap_rupees") val capRupees: Double = 0.0,
    )

    suspend fun fetch(): Result<FirstJobFree?> = runCatching {
        client.postgrest
            .rpc(function = "first_job_free_eligible")
            .decodeList<FirstJobFree>()
            .firstOrNull()
    }
}
