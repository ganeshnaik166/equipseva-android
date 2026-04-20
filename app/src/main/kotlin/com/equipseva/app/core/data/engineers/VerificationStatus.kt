package com.equipseva.app.core.data.engineers

enum class VerificationStatus(val storageKey: String, val displayName: String) {
    Pending("pending", "Pending review"),
    Verified("verified", "Verified"),
    Rejected("rejected", "Rejected");

    companion object {
        fun fromKey(key: String?): VerificationStatus =
            entries.firstOrNull { it.storageKey == key } ?: Pending
    }
}
