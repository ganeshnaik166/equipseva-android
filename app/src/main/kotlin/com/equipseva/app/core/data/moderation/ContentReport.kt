package com.equipseva.app.core.data.moderation

/**
 * What the user is reporting. The DB CHECK constraint on
 * `content_reports.target_type` accepts more values; we only list the ones
 * the client can actually produce so dead targets don't ship as buttons.
 */
enum class ContentReportTarget(val key: String) {
    ChatMessage("chat_message"),
    RepairJob("repair_job"),
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
