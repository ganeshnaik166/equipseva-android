package com.equipseva.app.core.data.orders

interface OrderRepository {
    /** Page 0-indexed. Filter by the signed-in user's id — server RLS is permissive so we double-enforce client-side. */
    suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<Order>>

    /** Inserts a new order row and returns the decoded domain model (id + order_number minted). */
    suspend fun insert(draft: OrderDraft): Result<Order>

    /** Fetch a single order by id. Null when nothing matches / not visible under RLS. */
    suspend fun fetchById(id: String): Result<Order?>

    /**
     * Record a non-terminal payment outcome (failed / cancelled / pending). The server-side
     * trigger in 20260419000000_razorpay_verification_rls.sql refuses anon-role writes that
     * would flip to `completed` / `confirmed` — those transitions are owned by the
     * verify-razorpay-payment edge function.
     */
    suspend fun markPaymentOutcome(
        id: String,
        paymentStatus: NonTerminalPaymentStatus,
        orderStatus: NonTerminalOrderStatus?,
    ): Result<Unit>
}

enum class NonTerminalPaymentStatus(val storageKey: String) {
    PENDING("pending"),
    FAILED("failed"),
    CANCELLED("cancelled"),
}

enum class NonTerminalOrderStatus(val storageKey: String) {
    DRAFT("draft"),
    CANCELLED("cancelled"),
}
