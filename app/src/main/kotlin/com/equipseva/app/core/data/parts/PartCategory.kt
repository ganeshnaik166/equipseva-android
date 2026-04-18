package com.equipseva.app.core.data.parts

/**
 * Spare-part categories observed in the live `spare_parts` table. The DB column
 * is `text` (not an enum), so we keep an `Other` fallback rather than crashing on
 * a value the supplier console adds tomorrow. `storageKey` is the wire format.
 */
enum class PartCategory(val storageKey: String, val displayName: String) {
    Cardiology("cardiology", "Cardiology"),
    ImagingRadiology("imaging_radiology", "Imaging & radiology"),
    LifeSupport("life_support", "Life support"),
    PatientMonitoring("patient_monitoring", "Patient monitoring"),
    Sterilization("sterilization", "Sterilization"),
    Other("other", "Other");

    companion object {
        val UserVisible: List<PartCategory> = entries.filter { it != Other }

        fun fromKey(key: String?): PartCategory =
            entries.firstOrNull { it.storageKey == key } ?: Other
    }
}
