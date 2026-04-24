package com.equipseva.app.core.data.orders

import com.equipseva.app.core.data.demo.DemoSeed
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [OrdersModule] when
 * `BuildConfig.DEMO_MODE` is true so the hospital My-Orders + supplier-side
 * dashboards render populated lists. Order mutations are no-ops.
 */
@Singleton
class FakeOrderRepository @Inject constructor() : OrderRepository {

    private val seed: List<Order> get() = DemoSeed.orders

    override suspend fun fetchMine(userId: String, page: Int, pageSize: Int): Result<List<Order>> {
        // Single demo buyer — every order belongs to DEMO_HOSPITAL_USER. Apply
        // pagination over the full sorted list.
        val sorted = seed.sortedByDescending { it.createdAtInstant ?: Instant.EPOCH }
        val from = (page * pageSize).coerceAtMost(sorted.size)
        val to = (from + pageSize).coerceAtMost(sorted.size)
        return Result.success(sorted.subList(from, to))
    }

    override suspend fun insert(draft: OrderDraft): Result<Order> =
        Result.failure(UnsupportedOperationException("Demo mode: order insert is disabled"))

    override suspend fun fetchById(id: String): Result<Order?> =
        Result.success(seed.firstOrNull { it.id == id })

    override suspend fun fetchForSupplier(supplierOrgId: String): Result<List<Order>> {
        val ids = DemoSeed.orderSupplierMap.entries.filter { it.value == supplierOrgId }.map { it.key }.toSet()
        return Result.success(seed.filter { it.id in ids })
    }

    override suspend fun markPaymentOutcome(
        id: String,
        paymentStatus: NonTerminalPaymentStatus,
        orderStatus: NonTerminalOrderStatus?,
    ): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: payment outcome writes are disabled"))

    override suspend fun cancelOrder(orderId: String): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: order cancellation is disabled"))

    override suspend fun confirmOrder(orderId: String): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: order confirm is disabled"))

    override suspend fun markShipped(orderId: String): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: markShipped is disabled"))
}
