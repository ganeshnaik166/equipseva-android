package com.equipseva.app.core.data.orders

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import java.security.SecureRandom
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseOrderRepository @Inject constructor(
    private val client: SupabaseClient,
) : OrderRepository {

    private val secureRandom = SecureRandom()

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

    override suspend fun insert(draft: OrderDraft): Result<com.equipseva.app.core.data.orders.Order> = runCatching {
        val payload = OrderInsertDto(
            orderNumber = mintOrderNumber(),
            buyerUserId = draft.buyerUserId,
            supplierOrgId = draft.supplierOrgId,
            items = draft.items,
            subtotal = draft.subtotalRupees,
            gstAmount = draft.gstRupees,
            shippingCost = draft.shippingRupees,
            totalAmount = draft.totalRupees,
            shippingAddress = draft.shippingAddress?.takeIf { it.isNotBlank() },
            shippingCity = draft.shippingCity?.takeIf { it.isNotBlank() },
            shippingState = draft.shippingState?.takeIf { it.isNotBlank() },
            shippingPincode = draft.shippingPincode?.takeIf { it.isNotBlank() },
            notes = draft.notes?.takeIf { it.isNotBlank() },
        )
        client.from(TABLE).insert(payload) {
            select()
        }.decodeSingle<OrderDto>().toDomain()
    }

    override suspend fun fetchById(id: String): Result<com.equipseva.app.core.data.orders.Order?> = runCatching {
        client.from(TABLE).select {
            filter { eq("id", id) }
            limit(count = 1)
        }.decodeList<OrderDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchForSupplier(supplierOrgId: String): Result<List<com.equipseva.app.core.data.orders.Order>> = runCatching {
        client.from(TABLE).select {
            filter { eq("supplier_org_id", supplierOrgId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<OrderDto>().map(OrderDto::toDomain)
    }

    override suspend fun markPaymentOutcome(
        id: String,
        paymentStatus: NonTerminalPaymentStatus,
        orderStatus: NonTerminalOrderStatus?,
    ): Result<Unit> = runCatching {
        client.from(TABLE).update({
            set("payment_status", paymentStatus.storageKey)
            orderStatus?.let { set("order_status", it.storageKey) }
        }) {
            filter { eq("id", id) }
        }
        Unit
    }

    override suspend fun cancelOrder(orderId: String): Result<Unit> = runCatching {
        client.from(TABLE).update({
            set("order_status", "cancelled")
            set("payment_status", "cancelled")
        }) {
            filter { eq("id", orderId) }
        }
        Unit
    }

    override suspend fun confirmOrder(orderId: String): Result<Unit> = runCatching {
        client.from(TABLE).update({
            set("order_status", OrderStatus.CONFIRMED.storageKey)
        }) {
            filter {
                eq("id", orderId)
                eq("order_status", OrderStatus.PLACED.storageKey)
            }
        }
        Unit
    }

    override suspend fun markShipped(orderId: String): Result<Unit> = runCatching {
        client.from(TABLE).update({
            set("order_status", OrderStatus.SHIPPED.storageKey)
        }) {
            filter {
                eq("id", orderId)
                eq("order_status", OrderStatus.CONFIRMED.storageKey)
            }
        }
        Unit
    }

    private fun mintOrderNumber(): String {
        val epochSeconds = System.currentTimeMillis() / 1000
        val suffix = secureRandom.nextInt(9000) + 1000
        return "ES-$epochSeconds-$suffix"
    }

    private companion object {
        const val TABLE = "spare_part_orders"
    }
}
