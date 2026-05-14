package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRepairBidRepository @Inject constructor(
    private val client: SupabaseClient,
) : RepairBidRepository {

    override suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?> = runCatching {
        val userId = client.auth.currentUserOrNull()?.id
        client.from(TABLE).select {
            filter {
                eq("repair_job_id", jobId)
                if (!userId.isNullOrBlank()) {
                    // Narrow to own row even when RLS would allow more (hospital
                    // side sees every bid on their job). The engineer-detail
                    // screen only ever wants its own row.
                    eq("engineer_user_id", userId)
                }
            }
            limit(count = 1)
        }.decodeList<RepairBidDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchBidsForJob(jobId: String): Result<List<RepairBid>> = runCatching {
        // PR-B: replaces the direct table SELECT with the enrichment RPC
        // so each bid card carries engineer name/avatar/rating/city +
        // distance_km without a per-row profile fetch. The RPC is RLS-
        // wrapped — it returns the same row scope the table SELECT did
        // (engineer sees own; hospital sees every bid on owned jobs).
        client.postgrest.rpc(
            function = "list_repair_job_bids_with_distance",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(jobId))
            },
        ).decodeList<RepairBidWithDistanceDto>().map(RepairBidWithDistanceDto::toDomain)
    }

    override suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int?,
        note: String?,
    ): Result<RepairBid> = runCatching {
        require(amountRupees.isFinite() && amountRupees in 1.0..MAX_BID_RUPEES) {
            "Bid amount must be between ₹1 and ₹1 crore"
        }
        require(etaHours == null || etaHours in 1..MAX_ETA_HOURS) {
            "ETA must be between 1 and $MAX_ETA_HOURS hours"
        }
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        val payload = RepairBidInsertDto(
            repairJobId = jobId,
            engineerUserId = userId,
            amountRupees = amountRupees,
            etaHours = etaHours,
            note = note?.takeIf { it.isNotBlank() },
        )
        client.from(TABLE).upsert(payload) {
            onConflict = "repair_job_id,engineer_user_id"
            select()
        }.decodeSingle<RepairBidDto>().toDomain()
    }

    override suspend fun withdrawBid(bidId: String): Result<Unit> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        client.from(TABLE).update({
            set("status", RepairBidStatus.Withdrawn.storageKey)
        }) {
            filter {
                eq("id", bidId)
                // Defense-in-depth: RLS enforces this server-side; the client-side filter makes a logic bug throw locally instead of silently no-op.
                eq("engineer_user_id", userId)
            }
        }
        Unit
    }

    override suspend fun acceptBid(bidId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "accept_repair_bid",
            parameters = buildJsonObject { put("p_bid_id", bidId) },
        )
        Unit
    }

    override suspend fun fetchMyBids(): Result<List<RepairBid>> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        client.from(TABLE).select {
            filter { eq("engineer_user_id", userId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RepairBidDto>().map(RepairBidDto::toDomain)
    }

    private companion object {
        const val TABLE = "repair_job_bids"
        // ₹1 crore — server enforces the same upper bound; client guards
        // so a slip-up doesn't round-trip an obviously wrong payload.
        const val MAX_BID_RUPEES: Double = 10_000_000.0
        // 30 days × 24h. Anything longer should be an AMC, not a one-shot bid.
        const val MAX_ETA_HOURS: Int = 720
    }
}
