package com.equipseva.app.core.data.rfq

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
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

    private companion object {
        const val RFQS = "rfqs"
        const val RFQ_BIDS = "rfq_bids"
    }
}
