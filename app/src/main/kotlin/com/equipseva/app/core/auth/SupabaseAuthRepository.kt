package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseAuthRepository @Inject constructor(
    private val client: SupabaseClient,
) : AuthRepository {

    override val sessionState: Flow<AuthSession> =
        client.auth.sessionStatus.map { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    val user = status.session.user
                    AuthSession.SignedIn(
                        userId = user?.id ?: "",
                        email = user?.email,
                    )
                }
                is SessionStatus.NotAuthenticated -> AuthSession.SignedOut
                is SessionStatus.Initializing -> AuthSession.Unknown
                is SessionStatus.RefreshFailure -> AuthSession.SignedOut
            }
        }

    override suspend fun sendPhoneOtp(phone: String): Result<Unit> = runCatching {
        // Server-side rate-limit gate. Returns NULL when allowed; an int (seconds
        // until next allowed) when the caller has hit 5 sends/hour for this phone.
        val retryAfter = client.postgrest.rpc(
            function = "phone_otp_can_request",
            parameters = kotlinx.serialization.json.buildJsonObject {
                put("p_phone", kotlinx.serialization.json.JsonPrimitive(phone))
            },
        ).data.toIntOrNull()
        if (retryAfter != null) {
            throw PhoneOtpRateLimitedException(retryAfterSeconds = retryAfter)
        }
        try {
            client.auth.signInWith(OTP) {
                this.phone = phone
            }
        } catch (t: Throwable) {
            throw mapTwilioTrialError(t)
        }
    }

    /** Raised when phone_otp_can_request RPC tells us the caller is throttled. */
    class PhoneOtpRateLimitedException(val retryAfterSeconds: Int) :
        RuntimeException("Too many OTP requests. Try again in ${retryAfterSeconds}s.")

    /**
     * Twilio trial accounts reject sends to non-verified numbers with error
     * 21608. The raw provider message is unhelpful; map it to a clear "this
     * number isn't whitelisted" string we can render. The original cause is
     * preserved so logs/Sentry can still see the full chain.
     */
    private fun mapTwilioTrialError(t: Throwable): Throwable {
        val msg = (t.message.orEmpty() + " " + (t.cause?.message.orEmpty())).lowercase()
        val trial = "21608" in msg ||
            ("unverified" in msg && "twilio" in msg) ||
            ("trial" in msg && "verified" in msg)
        if (!trial) return t
        return RuntimeException(
            "We can't send OTP to this number yet — our SMS provider is in trial " +
                "mode and only delivers to whitelisted numbers. Ask the team to " +
                "verify this number in the Twilio dashboard, or use a number " +
                "that's already verified.",
            t,
        )
    }

    override suspend fun verifyPhoneOtp(phone: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.SMS,
            phone = phone,
            token = token,
        )
    }

    override suspend fun requestPhoneAdd(phone: String): Result<Unit> = runCatching {
        val retryAfter = client.postgrest.rpc(
            function = "phone_otp_can_request",
            parameters = kotlinx.serialization.json.buildJsonObject {
                put("p_phone", kotlinx.serialization.json.JsonPrimitive(phone))
            },
        ).data.toIntOrNull()
        if (retryAfter != null) {
            throw PhoneOtpRateLimitedException(retryAfterSeconds = retryAfter)
        }
        try {
            client.auth.updateUser {
                this.phone = phone
            }
        } catch (t: Throwable) {
            throw mapTwilioTrialError(t)
        }
        Unit
    }

    override suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.PHONE_CHANGE,
            phone = phone,
            token = token,
        )
    }

    /**
     * Email OTP — KEPT for KYC's email-verify sheet. Not exposed via the
     * Welcome screen; not used for sign-in.
     */
    override suspend fun sendEmailOtp(email: String): Result<Unit> = runCatching {
        client.auth.signInWith(OTP) {
            this.email = email
        }
    }

    override suspend fun verifyEmailOtp(email: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyEmailOtp(
            type = io.github.jan.supabase.auth.OtpType.Email.EMAIL,
            email = email,
            token = token,
        )
    }

    override suspend fun updateEmail(newEmail: String): Result<Unit> = runCatching {
        client.auth.updateUser {
            email = newEmail
        }
        Unit
    }

    override suspend fun signOut(): Result<Unit> = runCatching {
        client.auth.signOut()
    }

    override suspend fun refreshSession(): Result<Unit> = runCatching {
        client.auth.refreshCurrentSession()
    }
}
