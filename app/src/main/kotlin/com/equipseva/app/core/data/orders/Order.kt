package com.equipseva.app.core.data.orders

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray

data class Order(
    val id: String,
    val orderNumber: String?,
    val status: OrderStatus,
    val paymentStatus: String?,
    val paymentId: String?,
    val subtotal: Double,
    val gstAmount: Double,
    val shippingCost: Double,
    val totalAmount: Double,
    val lineItems: List<OrderLineItem>,
    val shippingAddress: String?,
    val shippingCity: String?,
    val shippingState: String?,
    val shippingPincode: String?,
    val trackingNumber: String?,
    val estimatedDelivery: String?,
    val notes: String?,
    val createdAtIso: String?,
) {
    val lineItemCount: Int get() = lineItems.size
    val locationLine: String?
        get() = listOfNotNull(shippingCity, shippingState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }
}

private val lineItemJson = Json { ignoreUnknownKeys = true; isLenient = true }

internal fun OrderDto.toDomain(): Order {
    val parsed = (items as? JsonArray)
        ?.mapNotNull { element ->
            runCatching { lineItemJson.decodeFromJsonElement(OrderLineItem.serializer(), element) }.getOrNull()
        }
        .orEmpty()
    return Order(
        id = id,
        orderNumber = orderNumber,
        status = OrderStatus.fromKey(orderStatus),
        paymentStatus = paymentStatus,
        paymentId = paymentId,
        subtotal = subtotal,
        gstAmount = gstAmount ?: 0.0,
        shippingCost = shippingCost ?: 0.0,
        totalAmount = totalAmount,
        lineItems = parsed,
        shippingAddress = shippingAddress,
        shippingCity = shippingCity,
        shippingState = shippingState,
        shippingPincode = shippingPincode,
        trackingNumber = trackingNumber,
        estimatedDelivery = estimatedDelivery,
        notes = notes,
        createdAtIso = createdAt,
    )
}
