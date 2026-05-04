package com.equipseva.app.core.data.calls

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

@Singleton
class SupabaseVirtualCallRepository @Inject constructor(
    private val supabase: SupabaseClient,
) : VirtualCallRepository {

    override suspend fun requestCallSession(
        repairJobId: String,
    ): Result<VirtualCallRepository.CallSessionResult> = runCatching {
        val res = supabase.functions.invoke(
            function = "request-call-session",
            body = buildJsonObject {
                put("repair_job_id", JsonPrimitive(repairJobId))
            },
        )
        val text = res.bodyAsText()
        val status = res.status

        // Server errors come back as JSON with `code` + `message`.
        // Map well-known codes to typed CallSessionResult variants so
        // the screen can render the right UX (rate-limit toast,
        // "coming soon" sheet, etc.) without parsing the message.
        if (status.isSuccess()) {
            val parsed = JSON.decodeFromString(SuccessBody.serializer(), text)
            VirtualCallRepository.CallSessionResult.ClickToCall(
                message = parsed.message ?: "Connecting your call…",
                callSid = parsed.callSid,
            )
        } else {
            val err = runCatching { JSON.decodeFromString(ErrorBody.serializer(), text) }.getOrNull()
            mapError(status, err)
        }
    }

    private fun mapError(
        status: HttpStatusCode,
        err: ErrorBody?,
    ): VirtualCallRepository.CallSessionResult = when (err?.code) {
        "provider_not_configured" -> VirtualCallRepository.CallSessionResult.ProviderNotConfigured
        "rate_limited" -> VirtualCallRepository.CallSessionResult.RateLimited(
            message = err.message ?: "Too many call attempts today.",
        )
        "missing_phone" -> VirtualCallRepository.CallSessionResult.MissingPhone
        "not_participant" -> VirtualCallRepository.CallSessionResult.NotParticipant
        else -> VirtualCallRepository.CallSessionResult.Error(
            message = err?.message ?: "Couldn't start the call (HTTP ${status.value}).",
        )
    }

    @Serializable
    private data class SuccessBody(
        @SerialName("ok") val ok: Boolean = true,
        @SerialName("mode") val mode: String? = null,
        @SerialName("message") val message: String? = null,
        @SerialName("call_sid") val callSid: String? = null,
    )

    @Serializable
    private data class ErrorBody(
        @SerialName("ok") val ok: Boolean = false,
        @SerialName("code") val code: String? = null,
        @SerialName("message") val message: String? = null,
    )

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
