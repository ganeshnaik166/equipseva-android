package com.equipseva.app.features.profile

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Round 3775 — engineer profile completeness meter (round504
 * `engineer_profile_completeness`, unread by any client until now).
 * Pure read over already-live columns (KYC/aadhaar/PAN/police
 * verification, specializations, certificates, avatar, location,
 * profitability floor, GSTIN, completed-job count) — no dead
 * write-path dependency, unlike this migration's OTHER half
 * (`first_job_free_eligible`/`redeem_first_job_free`, deliberately
 * NOT built this round: `redeem_first_job_free` has zero callers
 * anywhere in the codebase — no trigger, no edge function — so
 * showing a hospital "you're eligible for ₹500 off" would promise a
 * discount that can never actually apply).
 */
@Singleton
class ProfileCompletenessRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Completeness(
        val score: Int,
        @SerialName("missing_items") val missingItems: List<String> = emptyList(),
        val band: String,
    )

    suspend fun fetchMyCompleteness(): Result<Completeness> = runCatching {
        client.postgrest.rpc(function = "engineer_profile_completeness").decodeSingle<Completeness>()
    }
}
