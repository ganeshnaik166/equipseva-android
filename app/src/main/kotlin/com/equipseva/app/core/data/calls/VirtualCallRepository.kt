package com.equipseva.app.core.data.calls

/**
 * Bridges the gap between the in-app "Call" CTA and Supabase's
 * request-call-session edge function, which fronts Exotel's
 * click-to-call API. The repo deliberately knows nothing about
 * Exotel — it speaks only the function's request/response shape so
 * we can swap providers later without touching call sites.
 */
interface VirtualCallRepository {

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
     * Attempt a masked-call bridge for the given repair job. The
     * caller is auto-resolved server-side from the JWT.
     */
    suspend fun requestCallSession(repairJobId: String): Result<CallSessionResult>
}
