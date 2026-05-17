package com.equipseva.app.features.amc

private val AMC_CATEGORY_OVERRIDES = mapOf(
    "ct_scan" to "CT Scan",
    "mri" to "MRI",
    "icu" to "ICU",
    "x_ray" to "X-ray",
    "ent" to "ENT",
)

internal fun amcCategoryLabel(key: String): String =
    AMC_CATEGORY_OVERRIDES[key] ?: key.split('_', '-').joinToString(" ") {
        it.replaceFirstChar { ch -> ch.uppercase() }
    }
