package com.equipseva.app.core.data.calls

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
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
        CallSessionResponseMapper.map(
            httpStatus = res.status.value,
            body = res.bodyAsText(),
        )
    }
}

/**
 * Pure mapping of the request-call-session edge function's HTTP response onto
 * the [VirtualCallRepository.CallSessionResult] sealed type. Pulled out of
 * [SupabaseVirtualCallRepository] so the error-shape contract is unit-testable
 * without spinning up a SupabaseClient / Ktor pipeline.
 *
 * The function contract this mirrors lives in
 * `supabase/functions/request-call-session/index.ts`.
 */
internal object CallSessionResponseMapper {

    private val json = Json { ignoreUnknownKeys = true }

    fun map(httpStatus: Int, body: String): VirtualCallRepository.CallSessionResult =
        if (httpStatus in 200..299) {
            val parsed = runCatching {
                json.decodeFromString(SuccessBody.serializer(), body)
            }.getOrNull()
            VirtualCallRepository.CallSessionResult.ClickToCall(
                message = parsed?.message ?: "Connecting your call…",
                callSid = parsed?.callSid,
            )
        } else {
            val err = runCatching {
                json.decodeFromString(ErrorBody.serializer(), body)
            }.getOrNull()
            mapError(httpStatus, err)
        }

    private fun mapError(
        httpStatus: Int,
        err: ErrorBody?,
    ): VirtualCallRepository.CallSessionResult = when (err?.code) {
        "provider_not_configured" -> VirtualCallRepository.CallSessionResult.ProviderNotConfigured
        "rate_limited" -> VirtualCallRepository.CallSessionResult.RateLimited(
            message = err.message ?: "Too many call attempts today.",
        )
        "missing_phone" -> VirtualCallRepository.CallSessionResult.MissingPhone
        "not_participant" -> VirtualCallRepository.CallSessionResult.NotParticipant
        else -> VirtualCallRepository.CallSessionResult.Error(
            message = err?.message ?: "Couldn't start the call (HTTP $httpStatus).",
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
}
