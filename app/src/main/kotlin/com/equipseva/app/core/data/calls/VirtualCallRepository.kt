package com.equipseva.app.core.data.calls

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/** Typed outcomes of an in-app masked-call attempt. */
sealed interface CallSessionResult {
    /** Exotel was reached and the click-to-call bridge is ringing both legs. */
    data class ClickToCall(val message: String, val callSid: String?) : CallSessionResult

    /** Exotel onboarding still in progress — show "calls coming soon" copy. */
    data object ProviderNotConfigured : CallSessionResult

    /** > 5 calls/job/day from this caller — server returned 429. */
    data class RateLimited(val message: String) : CallSessionResult

    /** Counterpart hasn't added a phone in their KYC yet. */
    data object MissingPhone : CallSessionResult

    /** Caller isn't a participant on the job. */
    data object NotParticipant : CallSessionResult

    /** Network / server error after the auth + participant checks pass. */
    data class Error(val message: String) : CallSessionResult
}

/**
 * Bridges the gap between the in-app "Call" CTA and Supabase's
 * request-call-session edge function, which fronts Exotel's
 * click-to-call API. The repo deliberately knows nothing about
 * Exotel — it speaks only the function's request/response shape so
 * we can swap providers later without touching call sites.
 */
@Singleton
class VirtualCallRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    /**
     * Attempt a masked-call bridge for the given repair job. The
     * caller is auto-resolved server-side from the JWT.
     */
    suspend fun requestCallSession(
        repairJobId: String,
    ): Result<CallSessionResult> = runCatching {
        // supabase-kt 3.x's Functions plugin auto-throws RestException on
        // any non-2xx response (see Functions.parseErrorResponse). We
        // catch it here so the typed error mapping below actually runs;
        // letting it bubble would surface a generic "Something went
        // wrong" toast and bury the 503/422/429 codes the edge function
        // returns.
        val res = try {
            supabase.functions.invoke(
                function = "request-call-session",
                body = buildJsonObject {
                    put("repair_job_id", JsonPrimitive(repairJobId))
                },
            )
        } catch (rest: RestException) {
            return@runCatching mapError(rest.statusCode, parseRestExceptionBody(rest))
        }
        val text = res.bodyAsText()
        val status = res.status

        if (status.isSuccess()) {
            val parsed = JSON.decodeFromString(SuccessBody.serializer(), text)
            CallSessionResult.ClickToCall(
                message = parsed.message ?: "Connecting your call…",
                callSid = parsed.callSid,
            )
        } else {
            // Defensive: if a future SDK upgrade stops auto-throwing,
            // we still parse the body the same way as the catch branch.
            val err = runCatching { JSON.decodeFromString(ErrorBody.serializer(), text) }.getOrNull()
            mapError(status.value, err)
        }
    }

    private fun parseRestExceptionBody(rest: RestException): ErrorBody? {
        // RestException carries the response body in `error` and the
        // human-readable message in `description`; either may hold the
        // raw JSON depending on supabase-kt's parser path. Try both.
        for (raw in listOfNotNull(rest.error, rest.description)) {
            if (raw.isBlank()) continue
            val parsed = runCatching { JSON.decodeFromString(ErrorBody.serializer(), raw) }.getOrNull()
            if (parsed?.code != null) return parsed
        }
        return ErrorBody(ok = false, code = null, message = rest.description?.takeIf { it.isNotBlank() })
    }

    private fun mapError(
        statusCode: Int,
        err: ErrorBody?,
    ): CallSessionResult = when (err?.code) {
        "provider_not_configured" -> CallSessionResult.ProviderNotConfigured
        "rate_limited" -> CallSessionResult.RateLimited(
            message = err.message ?: "Too many call attempts today.",
        )
        "missing_phone" -> CallSessionResult.MissingPhone
        "not_participant" -> CallSessionResult.NotParticipant
        else -> when (statusCode) {
            // Status-only fallback for when the body lacks a typed code
            // (e.g. edge router returns its own error envelope).
            503 -> CallSessionResult.ProviderNotConfigured
            422 -> CallSessionResult.MissingPhone
            403 -> CallSessionResult.NotParticipant
            429 -> CallSessionResult.RateLimited(
                message = err?.message ?: "Too many call attempts today.",
            )
            else -> CallSessionResult.Error(
                message = err?.message ?: "Couldn't start the call (HTTP $statusCode).",
            )
        }
    }

    @Serializable
    private data class SuccessBody(
        val ok: Boolean = true,
        val mode: String? = null,
        val message: String? = null,
        @SerialName("call_sid") val callSid: String? = null,
    )

    @Serializable
    private data class ErrorBody(
        val ok: Boolean = false,
        val code: String? = null,
        val message: String? = null,
    )

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
