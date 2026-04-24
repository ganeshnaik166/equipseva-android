package com.equipseva.app.core.data.moderation

/** What the user is reporting. Matches the CHECK constraint on `content_reports.target_type`. */
enum class ContentReportTarget(val key: String) {
    ChatMessage("chat_message"),
    PartListing("part_listing"),
    RepairJob("repair_job"),
    Rfq("rfq"),
    Profile("profile"),
}

/** Why the user is reporting it. Matches the CHECK constraint on `content_reports.reason`. */
enum class ContentReportReason(val key: String, val displayName: String) {
    Spam("spam", "Spam or scam"),
    Scam("scam", "Fraud / scam"),
    Abuse("abuse", "Abusive language"),
    Harassment("harassment", "Harassment"),
    Inappropriate("inappropriate", "Inappropriate content"),
    Illegal("illegal", "Illegal activity"),
    Other("other", "Something else"),
}
