package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRepairBidRepository @Inject constructor(
    private val client: SupabaseClient,
) : RepairBidRepository {

    override suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?> = runCatching {
        client.from(TABLE).select {
            filter {
                eq("repair_job_id", jobId)
            }
            limit(count = 1)
        }.decodeList<RepairBidDto>().firstOrNull()?.toDomain()
    }

    override suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int?,
        note: String?,
    ): Result<RepairBid> = runCatching {
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

    private companion object {
        const val TABLE = "repair_job_bids"
    }
}
