package com.equipseva.app.core.data.rfq

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRfqRepository @Inject constructor(
    private val client: SupabaseClient,
) : RfqRepository {

    override suspend fun fetchOpen(equipmentCategory: String?): Result<List<Rfq>> = runCatching {
        client.from(RFQS).select {
            filter {
                isIn("status", listOf("open", "published"))
                equipmentCategory?.let { eq("equipment_category", it) }
            }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RfqDto>().map(RfqDto::toDomain)
    }

    override suspend fun fetchByRequesterOrg(requesterOrgId: String): Result<List<Rfq>> = runCatching {
        client.from(RFQS).select {
            filter { eq("requester_org_id", requesterOrgId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RfqDto>().map(RfqDto::toDomain)
    }

    override suspend fun fetchBidsByManufacturer(manufacturerId: String): Result<List<RfqBid>> = runCatching {
        client.from(RFQ_BIDS).select {
            filter { eq("manufacturer_id", manufacturerId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RfqBidDto>().map(RfqBidDto::toDomain)
    }

    override suspend fun fetchBidsForRfq(rfqId: String): Result<List<RfqBid>> = runCatching {
        client.from(RFQ_BIDS).select {
            filter { eq("rfq_id", rfqId) }
            order("unit_price", order = Order.ASCENDING)
        }.decodeList<RfqBidDto>().map(RfqBidDto::toDomain)
    }

    override suspend fun fetchRfqById(rfqId: String): Result<Rfq> = runCatching {
        client.from(RFQS).select {
            filter { eq("id", rfqId) }
            limit(1)
        }.decodeSingle<RfqDto>().toDomain()
    }

    override suspend fun fetchRfqsByIds(ids: Collection<String>): Result<List<Rfq>> = runCatching {
        if (ids.isEmpty()) return@runCatching emptyList<Rfq>()
        client.from(RFQS).select {
            filter { isIn("id", ids.toList()) }
        }.decodeList<RfqDto>().map(RfqDto::toDomain)
    }

    override suspend fun createRfq(insert: RfqInsertDto): Result<Rfq> = runCatching {
        client.from(RFQS).insert(insert) {
            select()
        }.decodeSingle<RfqDto>().toDomain()
    }

    override suspend fun placeBid(insert: RfqBidInsertDto): Result<RfqBid> = runCatching {
        client.from(RFQ_BIDS).insert(insert) {
            select()
        }.decodeSingle<RfqBidDto>().toDomain()
    }

    override suspend fun acceptBid(bidId: String, rfqId: String): Result<RfqBid> = runCatching {
        // Flip parent RFQ to 'awarded' first so no more bids can be accepted concurrently.
        client.from(RFQS).update(StatusPatch(status = "awarded")) {
            filter {
                eq("id", rfqId)
                isIn("status", listOf("open", "published"))
            }
        }
        // Then flip the chosen bid. Separate filter on rfq_id prevents cross-RFQ mistakes.
        client.from(RFQ_BIDS).update(StatusPatch(status = "accepted")) {
            filter {
                eq("id", bidId)
                eq("rfq_id", rfqId)
            }
            select()
        }.decodeSingle<RfqBidDto>().toDomain()
    }

    @Serializable
    private data class StatusPatch(val status: String)

    private companion object {
        const val RFQS = "rfqs"
        const val RFQ_BIDS = "rfq_bids"
    }
}
