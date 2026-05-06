package com.equipseva.app.core.data.servicereport

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull

// v2.1 PR-D3 — wraps the compliance-report edge function +
// get_service_report_url RPC for the audit-trail HTML render.
//
// generate() always re-runs the edge function (cheap, idempotent), so
// the resulting HTML reflects current row state — useful when work_done
// or photos get edited after first completion.
@Singleton
class ServiceReportRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    @Serializable
    private data class GenerateResponse(
        @SerialName("ok") val ok: Boolean,
        @SerialName("service_report_url") val serviceReportUrl: String? = null,
        @SerialName("code") val code: String? = null,
        @SerialName("message") val message: String? = null,
    )

    suspend fun generate(jobId: String): Result<String> = runCatching {
        val res = try {
            supabase.functions.invoke(
                function = "generate_service_report",
                body = buildJsonObject {
                    put("job_id", JsonPrimitive(jobId))
                },
            )
        } catch (rest: RestException) {
            error(rest.description ?: "Couldn't generate service report")
        }
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            val parsed = runCatching { JSON.decodeFromString(GenerateResponse.serializer(), text) }
                .getOrNull()
            error(parsed?.message ?: "Couldn't generate service report (HTTP ${res.status.value})")
        }
        val parsed = JSON.decodeFromString(GenerateResponse.serializer(), text)
        parsed.serviceReportUrl ?: error(parsed.message ?: "missing url")
    }

    /** Cached signed URL stored on repair_jobs.service_report_url, if any. */
    suspend fun cachedUrl(jobId: String): Result<String?> = runCatching {
        val raw = supabase.postgrest.rpc(
            function = "get_service_report_url",
            parameters = buildJsonObject {
                put("p_job", JsonPrimitive(jobId))
            },
        ).data
        // RPC returns a bare JSON string or null. Parse defensively.
        if (raw.isBlank() || raw.equals("null", ignoreCase = true)) return@runCatching null
        val parsed = runCatching { JSON.parseToJsonElement(raw) }.getOrNull()
        (parsed as? JsonPrimitive)?.contentOrNull
    }

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
