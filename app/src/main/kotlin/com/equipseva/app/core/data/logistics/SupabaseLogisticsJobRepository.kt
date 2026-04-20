package com.equipseva.app.core.data.logistics

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseLogisticsJobRepository @Inject constructor(
    private val client: SupabaseClient,
) : LogisticsJobRepository {

    override suspend fun fetchPending(): Result<List<LogisticsJob>> = runCatching {
        client.from(TABLE).select {
            filter { isIn("status", listOf("pending", "quoted")) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<LogisticsJobDto>().map(LogisticsJobDto::toDomain)
    }

    override suspend fun fetchByPartnerAndStatuses(
        logisticsPartnerId: String,
        statuses: List<String>,
    ): Result<List<LogisticsJob>> = runCatching {
        client.from(TABLE).select {
            filter {
                eq("logistics_partner_id", logisticsPartnerId)
                if (statuses.isNotEmpty()) isIn("status", statuses)
            }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<LogisticsJobDto>().map(LogisticsJobDto::toDomain)
    }

    override suspend fun fetchAllByPartner(logisticsPartnerId: String): Result<List<LogisticsJob>> = runCatching {
        client.from(TABLE).select {
            filter { eq("logistics_partner_id", logisticsPartnerId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<LogisticsJobDto>().map(LogisticsJobDto::toDomain)
    }

    private companion object {
        const val TABLE = "logistics_jobs"
    }
}
