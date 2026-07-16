package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Hospital-chain admin cockpit data (round 549). The caller's chain(s) are read
 * straight from hospital_chains — its RLS SELECT policy already scopes rows to
 * `primary_admin_user_id = auth.uid()` (or founder), so a non-founder only ever
 * sees their own chains. chain_kpis / chain_per_site_summary are SECURITY
 * DEFINER RPCs re-gated to the chain admin. All read-only.
 */
@Singleton
class ChainRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Chain(
        @SerialName("id") val id: String,
        @SerialName("name") val name: String = "",
        @SerialName("status") val status: String = "active",
    )

    @Serializable
    data class ChainKpis(
        @SerialName("member_count") val memberCount: Int = 0,
        @SerialName("jobs_open") val jobsOpen: Int = 0,
        @SerialName("jobs_completed_window") val jobsCompletedWindow: Int = 0,
        @SerialName("jobs_disputed_window") val jobsDisputedWindow: Int = 0,
        @SerialName("amc_active") val amcActive: Int = 0,
        @SerialName("amc_pending_payment") val amcPendingPayment: Int = 0,
        @SerialName("total_escrow_held_rupees") val totalEscrowHeldRupees: Double = 0.0,
        @SerialName("open_dispute_packs") val openDisputePacks: Int = 0,
    )

    @Serializable
    data class ChainSite(
        @SerialName("hospital_user_id") val hospitalUserId: String = "",
        @SerialName("site_label") val siteLabel: String = "",
        @SerialName("jobs_open") val jobsOpen: Int = 0,
        @SerialName("jobs_completed_window") val jobsCompletedWindow: Int = 0,
        @SerialName("jobs_disputed_window") val jobsDisputedWindow: Int = 0,
        @SerialName("amc_active") val amcActive: Int = 0,
        @SerialName("escrow_held_rupees") val escrowHeldRupees: Double = 0.0,
    )

    suspend fun myChains(userId: String): Result<List<Chain>> = runCatching {
        client.postgrest.from("hospital_chains").select {
            filter { eq("primary_admin_user_id", userId) }
            order("name", Order.ASCENDING)
        }.decodeList<Chain>()
    }

    suspend fun kpis(chainId: String): Result<ChainKpis?> = runCatching {
        client.postgrest.rpc(
            function = "chain_kpis",
            parameters = buildJsonObject { put("p_chain_id", JsonPrimitive(chainId)) },
        ).decodeList<ChainKpis>().firstOrNull()
    }

    suspend fun perSite(chainId: String): Result<List<ChainSite>> = runCatching {
        client.postgrest.rpc(
            function = "chain_per_site_summary",
            parameters = buildJsonObject { put("p_chain_id", JsonPrimitive(chainId)) },
        ).decodeList<ChainSite>()
    }
}
