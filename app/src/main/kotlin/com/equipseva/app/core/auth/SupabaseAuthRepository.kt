package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.IDToken
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

    override suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit> =
        runCatching {
            client.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }
        }

    override suspend fun signUpWithEmailPassword(
        email: String,
        password: String,
        fullName: String,
    ): Result<Unit> = runCatching {
        client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
            this.data = kotlinx.serialization.json.buildJsonObject {
                put(
                    "full_name",
                    kotlinx.serialization.json.JsonPrimitive(fullName),
                )
            }
        }
        Unit
    }

    override suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit> =
        runCatching {
            client.auth.signInWith(IDToken) {
                this.idToken = idToken
                this.provider = Google
                this.nonce = nonce
            }
        }

    override suspend fun sendPasswordResetEmail(email: String): Result<Unit> = runCatching {
        client.auth.resetPasswordForEmail(email)
    }

    override suspend fun updatePassword(currentPassword: String, newPassword: String): Result<Unit> = runCatching {
        // Re-auth: verify the supplied current password against the active
        // session by attempting a fresh sign-in. Without this check an
        // unlocked-device attacker could swap the password and lock the
        // legitimate owner out — Supabase's updateUser doesn't gate on
        // proof of current credentials.
        val email = client.auth.currentUserOrNull()?.email
            ?: throw IllegalStateException("Not signed in")
        try {
            client.auth.signInWith(Email) {
                this.email = email
                this.password = currentPassword
            }
        } catch (ex: Throwable) {
            throw InvalidCurrentPasswordException().also { it.initCause(ex) }
        }
        client.auth.updateUser {
            password = newPassword
        }
        Unit
    }

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

    /** Raised when phone_otp_can_request RPC tells us the caller is throttled. */
    class PhoneOtpRateLimitedException(val retryAfterSeconds: Int) :
        RuntimeException("Too many OTP requests. Try again in ${retryAfterSeconds}s.")

    /**
     * Twilio trial accounts reject sends to non-verified numbers with error
     * 21608. Map that to a clear message; preserve the original cause for logs.
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

    override suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.PHONE_CHANGE,
            phone = phone,
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
