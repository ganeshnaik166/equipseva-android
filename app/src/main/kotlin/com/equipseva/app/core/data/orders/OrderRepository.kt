package com.equipseva.app.core.data.orders

interface OrderRepository {
    /** Page 0-indexed. Filter by the signed-in user's id — server RLS is permissive so we double-enforce client-side. */
    suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<Order>>
}
