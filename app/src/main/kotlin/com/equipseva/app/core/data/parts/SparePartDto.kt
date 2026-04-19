package com.equipseva.app.core.data.parts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape returned by Supabase Postgrest for a `spare_parts` row.
 *
 * Several columns are declared NOT NULL in the schema but actually return null
 * for older rows (e.g. discount_percentage). We keep nullable Kotlin types to
 * stay defensive — better than crashing the parser when an old supplier row
 * doesn't conform to the latest constraint.
 */
@Serializable
data class SparePartDto(
    val id: String,
    @SerialName("supplier_org_id") val supplierOrgId: String? = null,
    val name: String,
    @SerialName("part_number") val partNumber: String,
    val description: String = "",
    val category: String = "other",
    @SerialName("compatible_brands") val compatibleBrands: List<String>? = null,
    @SerialName("compatible_models") val compatibleModels: List<String>? = null,
    @SerialName("compatible_equipment_categories") val compatibleEquipmentCategories: List<String>? = null,
    val price: Double,
    val mrp: Double? = null,
    @SerialName("discount_percentage") val discountPercentage: Double? = null,
    @SerialName("stock_quantity") val stockQuantity: Int = 0,
    @SerialName("minimum_order_quantity") val minimumOrderQuantity: Int = 1,
    val unit: String = "piece",
    val images: List<String>? = null,
    @SerialName("is_genuine") val isGenuine: Boolean = false,
    @SerialName("is_oem") val isOem: Boolean = false,
    @SerialName("warranty_months") val warrantyMonths: Int = 0,
    val sku: String = "",
    @SerialName("hsn_code") val hsnCode: String = "",
    @SerialName("gst_rate") val gstRate: Double = 18.0,
    @SerialName("is_active") val isActive: Boolean = true,
)
