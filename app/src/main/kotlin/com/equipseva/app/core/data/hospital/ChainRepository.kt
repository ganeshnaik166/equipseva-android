package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
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

    // -----------------------------------------------------------------
    //  r1422 — site-onboarding invites
    // -----------------------------------------------------------------

    @Serializable
    data class ChainInvite(
        @SerialName("id") val id: String,
        @SerialName("invited_email") val invitedEmail: String = "",
        @SerialName("site_label") val siteLabel: String? = null,
        @SerialName("status") val status: String = "pending",
        @SerialName("expires_at") val expiresAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    /**
     * Invites for the caller's chain, newest first. Read straight from
     * hospital_chain_invites — its RLS SELECT policy already scopes rows to
     * the chain's primary admin (or founder).
     */
    suspend fun invites(chainId: String): Result<List<ChainInvite>> = runCatching {
        client.postgrest.from("hospital_chain_invites").select {
            filter { eq("chain_id", chainId) }
            order("created_at", Order.DESCENDING)
        }.decodeList<ChainInvite>()
    }

    /**
     * Invite a new site to the chain by admin email. Backed by
     * chain_admin_invite_site (SECURITY DEFINER, re-gated to the chain admin,
     * rate-limited server-side). The returned invite id is not needed here —
     * the screen just reloads the list.
     */
    suspend fun inviteSite(chainId: String, email: String, siteLabel: String?): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "chain_admin_invite_site",
            parameters = buildJsonObject {
                put("p_chain_id", JsonPrimitive(chainId))
                put("p_email", JsonPrimitive(email.trim()))
                put(
                    "p_site_label",
                    siteLabel?.trim()?.takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull,
                )
            },
        )
        Unit
    }

    /** Revoke a still-pending invite. Backed by chain_admin_revoke_invite. */
    suspend fun revokeInvite(inviteId: String, reason: String?): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "chain_admin_revoke_invite",
            parameters = buildJsonObject {
                put("p_invite_id", JsonPrimitive(inviteId))
                put(
                    "p_reason",
                    reason?.trim()?.takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull,
                )
            },
        )
        Unit
    }

    /**
     * Redeem a chain-site invite token (r1444) — the invited hospital joins the
     * chain. Backed by accept_hospital_chain_invite, which requires the caller's
     * email to match the invite's invited_email (so a token can't be replayed
     * from another account) and the invite to still be pending.
     */
    suspend fun acceptInvite(token: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "accept_hospital_chain_invite",
            parameters = buildJsonObject { put("p_invite_token", JsonPrimitive(token.trim())) },
        )
        Unit
    }
}
