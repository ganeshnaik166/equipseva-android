package com.equipseva.app.core.data.parts

import com.equipseva.app.core.data.demo.DemoSeed
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [PartsModule] when
 * `BuildConfig.DEMO_MODE` is true so the marketplace renders rich sample data
 * without hitting Supabase.
 */
@Singleton
class FakeSparePartsRepository @Inject constructor() : SparePartsRepository {

    private val seedById: Map<String, SparePart> = DemoSeed.spareParts.associateBy { it.id }

    override suspend fun fetchAvailable(
        query: String?,
        category: PartCategory?,
        sort: MarketplaceSort,
        page: Int,
        pageSize: Int,
    ): Result<List<SparePart>> {
        val q = query?.trim()?.lowercase().orEmpty()
        val filtered = DemoSeed.spareParts
            .asSequence()
            .filter { it.inStock }
            .filter { category == null || it.category == category }
            .filter {
                q.isEmpty() ||
                    it.name.lowercase().contains(q) ||
                    it.partNumber.lowercase().contains(q) ||
                    it.compatibleBrands.any { b -> b.lowercase().contains(q) } ||
                    it.compatibleModels.any { m -> m.lowercase().contains(q) }
            }
            .toList()

        val sorted = when (sort) {
            MarketplaceSort.PriceAsc -> filtered.sortedBy { it.priceRupees }
            MarketplaceSort.PriceDesc -> filtered.sortedByDescending { it.priceRupees }
            MarketplaceSort.Newest -> filtered.sortedByDescending { it.id }
            MarketplaceSort.Relevance -> filtered.sortedWith(
                compareByDescending<SparePart> { it.inStock }
                    .thenByDescending { it.discountPercent }
                    .thenBy { it.name },
            )
        }

        val from = (page * pageSize).coerceAtMost(sorted.size)
        val to = (from + pageSize).coerceAtMost(sorted.size)
        return Result.success(sorted.subList(from, to))
    }

    override suspend fun fetchById(id: String): Result<SparePart?> =
        Result.success(seedById[id])

    override suspend fun fetchBySupplier(supplierOrgId: String): Result<List<SparePart>> =
        Result.success(DemoSeed.spareParts.filter { it.supplierOrgId == supplierOrgId })

    override suspend fun fetchLowStockBySupplier(
        supplierOrgId: String,
        threshold: Int,
    ): Result<List<SparePart>> = Result.success(
        DemoSeed.spareParts.filter { it.supplierOrgId == supplierOrgId && it.stockQuantity <= threshold },
    )

    override suspend fun insertListing(dto: SparePartInsertDto): Result<SparePart> =
        Result.failure(UnsupportedOperationException("Demo mode: listing inserts are disabled"))
}
