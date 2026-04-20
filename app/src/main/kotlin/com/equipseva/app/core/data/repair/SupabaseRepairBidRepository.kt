package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
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
        client.from(TABLE).select {
            filter { eq("repair_job_id", jobId) }
            order("created_at", order = Order.ASCENDING)
        }.decodeList<RepairBidDto>().map(RepairBidDto::toDomain)
    }

    override suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int?,
        note: String?,
    ): Result<RepairBid> = runCatching {
        require(amountRupees.isFinite() && amountRupees in 1.0..10_000_000.0) {
            "Bid amount must be between ₹1 and ₹1 crore"
        }
        require(etaHours == null || etaHours in 1..720) {
            "ETA must be between 1 and 720 hours"
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
        client.from(TABLE).update({
            set("status", RepairBidStatus.Withdrawn.storageKey)
        }) {
            filter {
                eq("id", bidId)
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
    }
}
