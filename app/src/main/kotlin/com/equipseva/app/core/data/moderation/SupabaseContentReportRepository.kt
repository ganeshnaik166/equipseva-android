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
class SupabaseContentReportRepository @Inject constructor(
    private val client: SupabaseClient,
) : ContentReportRepository {

    override suspend fun submitReport(
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
                val trimmed = notes?.trim()?.takeIf { it.isNotEmpty() }
                put("notes", if (trimmed != null) JsonPrimitive(trimmed) else JsonNull)
            },
        )
    }
}
