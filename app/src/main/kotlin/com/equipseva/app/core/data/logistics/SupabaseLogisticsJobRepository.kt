package com.equipseva.app.core.data.logistics

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
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

    override suspend fun acceptJob(
        jobId: String,
        logisticsPartnerId: String,
    ): Result<LogisticsJob> = runCatching {
        client.from(TABLE).update(
            AcceptPatch(
                logisticsPartnerId = logisticsPartnerId,
                status = "assigned",
            ),
        ) {
            filter {
                eq("id", jobId)
                isIn("status", listOf("pending", "quoted"))
            }
            select()
        }.decodeSingle<LogisticsJobDto>().toDomain()
    }

    override suspend fun markInTransit(jobId: String): Result<LogisticsJob> = runCatching {
        client.from(TABLE).update(
            InTransitPatch(status = "in_transit"),
        ) {
            filter {
                eq("id", jobId)
                eq("status", "assigned")
            }
            select()
        }.decodeSingle<LogisticsJobDto>().toDomain()
    }

    override suspend fun markDelivered(jobId: String): Result<LogisticsJob> = runCatching {
        client.from(TABLE).update(
            DeliveredPatch(
                status = "delivered",
                actualDeliveryDate = Instant.now().toString(),
            ),
        ) {
            filter {
                eq("id", jobId)
                isIn("status", listOf("in_transit", "picked_up"))
            }
            select()
        }.decodeSingle<LogisticsJobDto>().toDomain()
    }

    @Serializable
    private data class AcceptPatch(
        @SerialName("logistics_partner_id") val logisticsPartnerId: String,
        val status: String,
    )

    @Serializable
    private data class InTransitPatch(
        val status: String,
    )

    @Serializable
    private data class DeliveredPatch(
        val status: String,
        @SerialName("actual_delivery_date") val actualDeliveryDate: String,
    )

    private companion object {
        const val TABLE = "logistics_jobs"
    }
}
