package com.equipseva.app.core.data.orders

interface OrderRepository {
    /** Page 0-indexed. Filter by the signed-in user's id — server RLS is permissive so we double-enforce client-side. */
    suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<Order>>

    /** Inserts a new order row and returns the decoded domain model (id + order_number minted). */
    suspend fun insert(draft: OrderDraft): Result<Order>

    /** Fetch a single order by id. Null when nothing matches / not visible under RLS. */
    suspend fun fetchById(id: String): Result<Order?>

    /** Patch payment_id + payment_status + order_status after a Razorpay callback resolves. */
    suspend fun markPayment(
        id: String,
        paymentId: String?,
        paymentStatus: String,
        orderStatus: String?,
    ): Result<Unit>
}
