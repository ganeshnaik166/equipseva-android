package com.equipseva.app.core.data.parts

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseSparePartsRepository @Inject constructor(
    private val client: SupabaseClient,
) : SparePartsRepository {

    override suspend fun fetchAvailable(
        query: String?,
        category: PartCategory?,
        sort: MarketplaceSort,
        page: Int,
        pageSize: Int,
    ): Result<List<SparePart>> = runCatching {
        val from = (page.coerceAtLeast(0)).toLong() * pageSize
        val to = from + pageSize - 1

        client.from(TABLE).select {
            filter {
                eq("is_active", true)
                category?.let { eq("category", it.storageKey) }
                if (!query.isNullOrBlank()) {
                    val needle = query.trim().sanitizeForIlike()
                    or {
                        ilike("name", "%$needle%")
                        ilike("part_number", "%$needle%")
                    }
                }
            }
            when (sort) {
                MarketplaceSort.Relevance -> {
                    // Cheap relevance: in-stock first, then most recent.
                    order("stock_quantity", order = Order.DESCENDING)
                    order("created_at", order = Order.DESCENDING)
                }
                MarketplaceSort.PriceAsc -> order("price", order = Order.ASCENDING)
                MarketplaceSort.PriceDesc -> order("price", order = Order.DESCENDING)
                MarketplaceSort.Newest -> order("created_at", order = Order.DESCENDING)
            }
            range(from, to)
        }.decodeList<SparePartDto>().map(SparePartDto::toDomain)
    }

    override suspend fun fetchById(id: String): Result<SparePart?> = runCatching {
        client.from(TABLE).select {
            filter {
                eq("id", id)
                eq("is_active", true)
            }
            limit(count = 1)
        }.decodeList<SparePartDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchBySupplier(supplierOrgId: String): Result<List<SparePart>> = runCatching {
        client.from(TABLE).select {
            filter { eq("supplier_org_id", supplierOrgId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<SparePartDto>().map(SparePartDto::toDomain)
    }

    override suspend fun fetchLowStockBySupplier(
        supplierOrgId: String,
        threshold: Int,
    ): Result<List<SparePart>> = runCatching {
        client.from(TABLE).select {
            filter {
                eq("supplier_org_id", supplierOrgId)
                lte("stock_quantity", threshold)
            }
            order("stock_quantity", order = Order.ASCENDING)
        }.decodeList<SparePartDto>().map(SparePartDto::toDomain)
    }

    override suspend fun insertListing(dto: SparePartInsertDto): Result<SparePart> = runCatching {
        client.from(TABLE).insert(dto) {
            select()
        }.decodeSingle<SparePartDto>().toDomain()
    }

    private fun String.sanitizeForIlike(): String =
        replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    private companion object {
        const val TABLE = "spare_parts"
    }
}
