package com.equipseva.app.core.data.repair

/**
 * Mirrors the `job_status` enum on the Supabase side. Wire values are the raw
 * strings Postgrest returns; everything else in the app speaks the enum.
 *
 * If the server adds a new status tomorrow we fall into [Unknown] rather than
 * crashing — the enum is not exhaustive against future releases.
 */
enum class RepairJobStatus(val storageKey: String, val displayName: String) {
    Requested("requested", "Open"),
    Assigned("assigned", "Assigned"),
    EnRoute("en_route", "En route"),
    InProgress("in_progress", "In progress"),
    Completed("completed", "Completed"),
    Cancelled("cancelled", "Cancelled"),
    Disputed("disputed", "Disputed"),
    Unknown("", "Unknown");

    companion object {
        fun fromKey(key: String?): RepairJobStatus =
            entries.firstOrNull { it.storageKey == key } ?: Unknown

        /**
         * Statuses an engineer can act on from the feed. `requested` is the common
         * open-for-bidding bucket; `assigned` is included so engineers who have
         * just been picked still see the job on the feed until they accept or move
         * it forward.
         */
        val OpenForEngineers: List<RepairJobStatus> = listOf(Requested, Assigned)
    }
}

enum class RepairJobUrgency(val storageKey: String, val displayName: String) {
    Emergency("emergency", "Emergency"),
    SameDay("same_day", "Same day"),
    Scheduled("scheduled", "Scheduled"),
    Unknown("", "Standard");

    companion object {
        fun fromKey(key: String?): RepairJobUrgency =
            entries.firstOrNull { it.storageKey == key } ?: Unknown
    }
}

enum class RepairEquipmentCategory(val storageKey: String, val displayName: String) {
    ImagingRadiology("imaging_radiology", "Imaging & radiology"),
    PatientMonitoring("patient_monitoring", "Patient monitoring"),
    LifeSupport("life_support", "Life support"),
    Surgical("surgical", "Surgical"),
    Laboratory("laboratory", "Laboratory"),
    Dental("dental", "Dental"),
    Ophthalmology("ophthalmology", "Ophthalmology"),
    Physiotherapy("physiotherapy", "Physiotherapy"),
    Neonatal("neonatal", "Neonatal"),
    Sterilization("sterilization", "Sterilization"),
    HospitalFurniture("hospital_furniture", "Hospital furniture"),
    Dialysis("dialysis", "Dialysis"),
    Oncology("oncology", "Oncology"),
    Cardiology("cardiology", "Cardiology"),
    Ent("ent", "ENT"),
    Other("other", "Other");

    companion object {
        fun fromKey(key: String?): RepairEquipmentCategory =
            entries.firstOrNull { it.storageKey == key } ?: Other
    }
}
