package com.equipseva.app.core.data.orders

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseOrderRepository @Inject constructor(
    private val client: SupabaseClient,
) : OrderRepository {

    override suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<com.equipseva.app.core.data.orders.Order>> = runCatching {
        val from = page.coerceAtLeast(0).toLong() * pageSize
        val to = from + pageSize - 1
        client.from(TABLE).select {
            filter {
                eq("buyer_user_id", userId)
            }
            order("created_at", order = Order.DESCENDING)
            range(from, to)
        }.decodeList<OrderDto>().map(OrderDto::toDomain)
    }

    private companion object {
        const val TABLE = "spare_part_orders"
    }
}
