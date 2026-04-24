package com.equipseva.app.core.data.moderation

interface ContentReportRepository {
    /**
     * Submit a report against a piece of user-generated content. RLS pins
     * the reporter to the current auth.uid; the client never authors that.
     */
    suspend fun submitReport(
        target: ContentReportTarget,
        targetId: String,
        reason: ContentReportReason,
        notes: String?,
    ): Result<Unit>
}
