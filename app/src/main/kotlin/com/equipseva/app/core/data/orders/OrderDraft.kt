package com.equipseva.app.core.data.orders

/**
 * Everything the checkout flow needs to hand over to [OrderRepository.insert]. Totals are
 * computed by the caller from the cart; the repo just serialises and writes.
 */
data class OrderDraft(
    val buyerUserId: String,
    val supplierOrgId: String,
    val items: List<OrderLineItem>,
    val subtotalRupees: Double,
    val gstRupees: Double,
    val shippingRupees: Double,
    val totalRupees: Double,
    val shippingAddress: String?,
    val shippingCity: String?,
    val shippingState: String?,
    val shippingPincode: String?,
    val notes: String? = null,
)
