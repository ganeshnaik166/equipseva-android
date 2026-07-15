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
                // Cap at 1000 to match the STRICTEST active server CHECK.
                // content_reports has TWO coexisting note-length checks:
                // content_reports_notes_len (char_length<=1000, from the base
                // table) and content_reports_notes_length_chk (length<=4000,
                // added later, additive). The base 1000 was never dropped, so
                // 1000 governs — a 1001..4000-char note passes .take() but
                // hits a 23514. UI already clamps to 1000; this covers non-UI
                // callers (tests, scripts, future programmatic flows).
                val trimmed = notes?.trim()?.takeIf { it.isNotEmpty() }?.take(1000)
                put("notes", if (trimmed != null) JsonPrimitive(trimmed) else JsonNull)
            },
        )
    }
}
