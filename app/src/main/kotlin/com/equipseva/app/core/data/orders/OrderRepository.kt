package com.equipseva.app.core.data.orders

interface OrderRepository {
    /** Page 0-indexed. Filter by the signed-in user's id — server RLS is permissive so we double-enforce client-side. */
    suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<Order>>

    /** Inserts a new order row and returns the decoded domain model (id + order_number minted). */
    suspend fun insert(draft: OrderDraft): Result<Order>

    /** Fetch a single order by id. Null when nothing matches / not visible under RLS. */
    suspend fun fetchById(id: String): Result<Order?>

    /** Orders placed against this supplier org — supplier-side dashboard view. */
    suspend fun fetchForSupplier(supplierOrgId: String): Result<List<Order>>

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

    /**
     * Cancel an order placed by the buyer. Sets both `order_status` and `payment_status` to
     * `cancelled`. Server-side trigger in 20260419000000_razorpay_verification_rls.sql allows
     * the anon role to flip to these non-terminal cancelled states.
     */
    suspend fun cancelOrder(orderId: String): Result<Unit>

    /**
     * Supplier acknowledges an incoming order, moving `order_status` from `placed` to
     * `confirmed`. The PATCH is filtered server-side to `order_status='placed'` so a
     * duplicate press can't regress a row that another path (e.g. Razorpay verification)
     * already flipped to confirmed.
     *
     * Supplier-side update policy + relaxed guard trigger live in
     * 20260423000000_supplier_order_fulfillment.sql.
     */
    suspend fun confirmOrder(orderId: String): Result<Unit>

    /**
     * Supplier marks the order as shipped. Only applies when the row is currently in
     * `confirmed`. There is no dedicated `shipped_at` column in `spare_part_orders`, so we
     * only update `order_status`; tracking metadata is a later milestone.
     */
    suspend fun markShipped(orderId: String): Result<Unit>
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
