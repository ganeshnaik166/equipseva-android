package com.equipseva.app.core.data.parts

interface SparePartsRepository {
    /**
     * Server-side filtered query against `public.spare_parts`.
     *
     * @param query free-text search against `name` / `part_number` (ILIKE).
     * @param category optional category filter; `null` = all categories.
     * @param page zero-based page index.
     * @param pageSize how many rows per page.
     */
    suspend fun fetchAvailable(
        query: String? = null,
        category: PartCategory? = null,
        sort: MarketplaceSort = MarketplaceSort.Relevance,
        page: Int = 0,
        pageSize: Int = 20,
    ): Result<List<SparePart>>

    /** Fetch a single part by id. Returns `null` if not found / inactive. */
    suspend fun fetchById(id: String): Result<SparePart?>

    /** All parts owned by the given supplier org — includes inactive/out-of-stock. */
    suspend fun fetchBySupplier(supplierOrgId: String): Result<List<SparePart>>

    /** Parts where `stock_quantity <= threshold` (default 5) — drives stock-alerts. */
    suspend fun fetchLowStockBySupplier(
        supplierOrgId: String,
        threshold: Int = 5,
    ): Result<List<SparePart>>

    /**
     * Insert a new spare-part listing for a supplier.
     * Returns the persisted [SparePart] (round-tripped through the DTO so server
     * defaults like `id` and `created_at` are included).
     * RLS will reject inserts whose `supplier_org_id` doesn't match the caller.
     */
    suspend fun insertListing(dto: SparePartInsertDto): Result<SparePart>
}
