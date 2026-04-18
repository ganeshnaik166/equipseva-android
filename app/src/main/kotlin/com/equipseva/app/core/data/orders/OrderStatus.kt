package com.equipseva.app.core.data.orders

/**
 * Mirrors the Postgres `order_status` enum on `public.spare_part_orders.order_status`.
 * UNKNOWN guards against the server adding a new value before we ship an app update.
 */
enum class OrderStatus(val storageKey: String, val displayName: String) {
    PLACED("placed", "Placed"),
    CONFIRMED("confirmed", "Confirmed"),
    SHIPPED("shipped", "Shipped"),
    DELIVERED("delivered", "Delivered"),
    CANCELLED("cancelled", "Cancelled"),
    RETURNED("returned", "Returned"),
    UNKNOWN("unknown", "Unknown");

    companion object {
        fun fromKey(key: String?): OrderStatus =
            entries.firstOrNull { it.storageKey == key } ?: UNKNOWN
    }
}
