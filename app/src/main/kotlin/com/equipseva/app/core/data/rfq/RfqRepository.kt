package com.equipseva.app.core.data.rfq

interface RfqRepository {
    /** Open RFQs visible to manufacturers to bid on. Filter by equipment category when provided. */
    suspend fun fetchOpen(equipmentCategory: String? = null): Result<List<Rfq>>

    /** RFQs raised by the given requester org — hospital-side dashboard. */
    suspend fun fetchByRequesterOrg(requesterOrgId: String): Result<List<Rfq>>

    /** All bids placed by the given manufacturer — manufacturer lead pipeline. */
    suspend fun fetchBidsByManufacturer(manufacturerId: String): Result<List<RfqBid>>

    /** Bulk-fetch RFQs by id — used to decorate manufacturer bids with parent-RFQ context. */
    suspend fun fetchRfqsByIds(ids: Collection<String>): Result<List<Rfq>>

    /** Insert a new RFQ row and return the decoded domain model. */
    suspend fun createRfq(insert: RfqInsertDto): Result<Rfq>
}
