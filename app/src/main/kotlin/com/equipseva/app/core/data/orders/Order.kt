package com.equipseva.app.core.data.orders

import kotlinx.serialization.json.JsonArray

data class Order(
    val id: String,
    val orderNumber: String?,
    val status: OrderStatus,
    val paymentStatus: String?,
    val subtotal: Double,
    val gstAmount: Double,
    val shippingCost: Double,
    val totalAmount: Double,
    val lineItemCount: Int,
    val shippingCity: String?,
    val shippingState: String?,
    val trackingNumber: String?,
    val estimatedDelivery: String?,
    val createdAtIso: String?,
) {
    val locationLine: String?
        get() = listOfNotNull(shippingCity, shippingState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }
}

internal fun OrderDto.toDomain(): Order = Order(
    id = id,
    orderNumber = orderNumber,
    status = OrderStatus.fromKey(orderStatus),
    paymentStatus = paymentStatus,
    subtotal = subtotal,
    gstAmount = gstAmount ?: 0.0,
    shippingCost = shippingCost ?: 0.0,
    totalAmount = totalAmount,
    lineItemCount = (items as? JsonArray)?.size ?: 0,
    shippingCity = shippingCity,
    shippingState = shippingState,
    trackingNumber = trackingNumber,
    estimatedDelivery = estimatedDelivery,
    createdAtIso = createdAt,
)
