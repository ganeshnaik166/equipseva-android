package com.equipseva.app.core.data.repair

enum class RepairBidStatus(val storageKey: String, val displayName: String) {
    Pending("pending", "Pending"),
    Withdrawn("withdrawn", "Withdrawn"),
    Accepted("accepted", "Accepted"),
    Rejected("rejected", "Rejected"),
    Unknown("", "Unknown");

    companion object {
        fun fromKey(key: String?): RepairBidStatus =
            entries.firstOrNull { it.storageKey == key } ?: Unknown
    }
}
