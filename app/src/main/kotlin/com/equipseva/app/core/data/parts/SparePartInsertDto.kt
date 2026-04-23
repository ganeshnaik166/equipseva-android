package com.equipseva.app.core.data.parts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for inserting into `spare_parts`. Excludes server-generated fields
 * (id, created_at, updated_at) and lets the DB supply defaults for everything we
 * don't explicitly send. Optional text fields are nullable so we can serialize
 * `null` (rather than empty string) when the supplier left a field blank.
 *
 * Mirrors `OrderInsertDto` style.
 */
@Serializable
data class SparePartInsertDto(
    @SerialName("supplier_org_id") val supplierOrgId: String?,
    val name: String,
    @SerialName("part_number") val partNumber: String,
    val category: String,
    val price: Double,
    @SerialName("stock_quantity") val stockQuantity: Int,
    val description: String? = null,
    val mrp: Double? = null,
    @SerialName("gst_rate") val gstRate: Double = 18.0,
    @SerialName("warranty_months") val warrantyMonths: Int = 0,
    val sku: String? = null,
    @SerialName("hsn_code") val hsnCode: String? = null,
    @SerialName("is_genuine") val isGenuine: Boolean = false,
    @SerialName("is_oem") val isOem: Boolean = false,
    @SerialName("discount_percentage") val discountPercentage: Int = 0,
)
