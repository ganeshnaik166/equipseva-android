package com.equipseva.app.core.data.orders

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * Wire shape for `public.spare_part_orders`. Numeric columns map to Double rather than
 * BigDecimal because kotlinx.serialization's default support for BigDecimal is Android-
 * hostile; the rupee totals we store (<100k per order) fit in a Double with no precision
 * loss at 2 decimal places.
 *
 * `items` is a jsonb blob of line-item objects; we keep the raw JsonElement so the Orders
 * list can render a line count without a separate query, and detail views can decode the
 * structured shape in a later phase.
 */
@Serializable
data class OrderDto(
    val id: String,
    @SerialName("order_number") val orderNumber: String? = null,
    @SerialName("buyer_org_id") val buyerOrgId: String? = null,
    @SerialName("buyer_user_id") val buyerUserId: String,
    @SerialName("supplier_org_id") val supplierOrgId: String,
    @SerialName("related_repair_job_id") val relatedRepairJobId: String? = null,
    val items: JsonElement? = null,
    val subtotal: Double,
    @SerialName("gst_amount") val gstAmount: Double? = 0.0,
    @SerialName("shipping_cost") val shippingCost: Double? = 0.0,
    @SerialName("total_amount") val totalAmount: Double,
    @SerialName("shipping_address") val shippingAddress: String? = null,
    @SerialName("shipping_city") val shippingCity: String? = null,
    @SerialName("shipping_state") val shippingState: String? = null,
    @SerialName("shipping_pincode") val shippingPincode: String? = null,
    @SerialName("order_status") val orderStatus: String? = null,
    @SerialName("payment_status") val paymentStatus: String? = null,
    @SerialName("payment_id") val paymentId: String? = null,
    @SerialName("tracking_number") val trackingNumber: String? = null,
    @SerialName("estimated_delivery") val estimatedDelivery: String? = null,
    @SerialName("delivered_at") val deliveredAt: String? = null,
    @SerialName("invoice_url") val invoiceUrl: String? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
