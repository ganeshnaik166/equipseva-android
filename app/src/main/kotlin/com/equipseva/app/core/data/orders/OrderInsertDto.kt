package com.equipseva.app.core.data.orders

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for inserting into `spare_part_orders`. Excludes server-generated fields
 * (id, created_at, updated_at) and lets the DB supply defaults for order/payment status.
 * `order_number` is uniqueness-constrained and has no default, so the client mints one.
 */
@Serializable
internal data class OrderInsertDto(
    @SerialName("order_number") val orderNumber: String,
    @SerialName("buyer_user_id") val buyerUserId: String,
    @SerialName("supplier_org_id") val supplierOrgId: String,
    val items: List<OrderLineItem>,
    val subtotal: Double,
    @SerialName("gst_amount") val gstAmount: Double,
    @SerialName("shipping_cost") val shippingCost: Double,
    @SerialName("total_amount") val totalAmount: Double,
    @SerialName("shipping_address") val shippingAddress: String? = null,
    @SerialName("shipping_city") val shippingCity: String? = null,
    @SerialName("shipping_state") val shippingState: String? = null,
    @SerialName("shipping_pincode") val shippingPincode: String? = null,
    val notes: String? = null,
)
