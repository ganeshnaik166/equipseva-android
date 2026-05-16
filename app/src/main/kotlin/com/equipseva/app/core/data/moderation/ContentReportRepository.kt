package com.equipseva.app.core.data.moderation

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ContentReportRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    /**
     * Submit a report against a piece of user-generated content. RLS pins
     * the reporter to the current auth.uid; the client never authors that.
     */
    suspend fun submitReport(
        target: ContentReportTarget,
        targetId: String,
        reason: ContentReportReason,
        notes: String?,
    ): Result<Unit> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "Not signed in"
        }
        client.from("content_reports").insert(
            buildJsonObject {
                put("reporter_user_id", JsonPrimitive(userId))
                put("target_type", JsonPrimitive(target.key))
                put("target_id", JsonPrimitive(targetId))
                put("reason", JsonPrimitive(reason.key))
                // Cap matches the server-side CHECK
                // content_reports_notes_length_chk (4000). UI input
                // (ReportContentSheet) already clamps to 1000 in the
                // text field, but defense-in-depth at the repository
                // boundary covers non-UI callers (tests, scripts,
                // future programmatic flows) so they can't ship a
                // multi-MB string and get a 23514 rejection.
                val trimmed = notes?.trim()?.takeIf { it.isNotEmpty() }?.take(4000)
                put("notes", if (trimmed != null) JsonPrimitive(trimmed) else JsonNull)
            },
        )
    }
}
