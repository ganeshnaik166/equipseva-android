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
        page: Int = 0,
        pageSize: Int = 20,
    ): Result<List<SparePart>>

    /** Fetch a single part by id. Returns `null` if not found / inactive. */
    suspend fun fetchById(id: String): Result<SparePart?>
}
