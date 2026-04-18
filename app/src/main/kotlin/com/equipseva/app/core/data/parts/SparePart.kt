package com.equipseva.app.core.data.parts

/**
 * UI-facing model. Anything the screen needs is non-nullable here; whatever the
 * DTO leaves null we either default or compute. Keeping the wire shape and the
 * domain shape separate means RLS-safe column changes don't ripple into UI code.
 */
data class SparePart(
    val id: String,
    val name: String,
    val partNumber: String,
    val description: String,
    val category: PartCategory,
    val compatibleBrands: List<String>,
    val compatibleModels: List<String>,
    val priceRupees: Double,
    val mrpRupees: Double?,
    val discountPercent: Int,
    val stockQuantity: Int,
    val minimumOrderQuantity: Int,
    val unit: String,
    val imageUrls: List<String>,
    val isGenuine: Boolean,
    val isOem: Boolean,
    val warrantyMonths: Int,
    val sku: String,
    val gstRatePercent: Double,
) {
    val inStock: Boolean get() = stockQuantity > 0
    val primaryImageUrl: String? get() = imageUrls.firstOrNull()
}

internal fun SparePartDto.toDomain(): SparePart {
    val price = price
    val mrp = mrp?.takeIf { it > 0.0 }
    val discount = when {
        discountPercentage != null && discountPercentage > 0.0 -> discountPercentage.toInt()
        mrp != null && mrp > price -> (((mrp - price) / mrp) * 100).toInt()
        else -> 0
    }
    return SparePart(
        id = id,
        name = name,
        partNumber = partNumber,
        description = description,
        category = PartCategory.fromKey(category),
        compatibleBrands = compatibleBrands,
        compatibleModels = compatibleModels,
        priceRupees = price,
        mrpRupees = mrp,
        discountPercent = discount.coerceIn(0, 99),
        stockQuantity = stockQuantity,
        minimumOrderQuantity = minimumOrderQuantity,
        unit = unit,
        imageUrls = images.filter { it.isNotBlank() },
        isGenuine = isGenuine,
        isOem = isOem,
        warrantyMonths = warrantyMonths,
        sku = sku,
        gstRatePercent = gstRate,
    )
}
