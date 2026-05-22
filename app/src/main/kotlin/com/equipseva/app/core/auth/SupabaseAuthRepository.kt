package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.SignOutScope
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
        role: com.equipseva.app.features.auth.UserRole,
    ): Result<SignUpOutcome> = runCatching {
        client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
            this.data = kotlinx.serialization.json.buildJsonObject {
                put(
                    "full_name",
                    kotlinx.serialization.json.JsonPrimitive(fullName),
                )
                // Picked up by the public.handle_new_user() trigger on
                // auth.users insert so the profiles row gets the right role
                // even when "Confirm email" is on (no session post-signup).
                put(
                    "role",
                    kotlinx.serialization.json.JsonPrimitive(role.storageKey),
                )
            }
        }
        // When Supabase has "Confirm email" ON, signUp returns success but
        // doesn't issue a session — the user must click the verification
        // link first. When it's OFF, currentSessionOrNull is non-null and
        // SessionViewModel will pick up SignedIn for an automatic redirect.
        if (client.auth.currentSessionOrNull() != null) {
            SignUpOutcome.AutoSignedIn
        } else {
            SignUpOutcome.NeedsEmailConfirmation
        }
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
        // Land users on the hosted reset page on equipseva.com (GitHub
        // Pages, see docs/auth/reset.html). The page captures the recovery
        // token Supabase appends as a URL fragment, prompts for a new
        // password, and calls supabase-js's updateUser to set it. The user
        // then signs in with the new password — no app deep link needed for v1.
        client.auth.resetPasswordForEmail(
            email = email,
            redirectUrl = "https://equipseva.com/auth/reset",
        )
    }

    override suspend fun updatePassword(currentPassword: String, newPassword: String): Result<Unit> = runCatching {
        // Re-auth: verify the supplied current password against the active
        // session by attempting a fresh sign-in. Without this check an
        // unlocked-device attacker could swap the password and lock the
        // legitimate owner out — Supabase's updateUser doesn't gate on
        // proof of current credentials.
        verifyCurrentPassword(currentPassword).getOrThrow()
        client.auth.updateUser {
            password = newPassword
        }
        Unit
    }

    override suspend fun verifyCurrentPassword(password: String): Result<Unit> = runCatching {
        // Shared re-auth helper — used by updatePassword (don't lock the
        // owner out) + delete_my_account (don't let an attacker nuke the
        // account on an unlocked device). The attempt itself fires a
        // fresh sign-in against the same identity; on success Supabase
        // rotates the session token but the active user id stays the
        // same. On wrong password we surface the typed InvalidCurrent
        // exception so callers can pin the error on the password field.
        val email = client.auth.currentUserOrNull()?.email
            ?: throw IllegalStateException("Not signed in")
        try {
            client.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }
        } catch (ex: Throwable) {
            throw InvalidCurrentPasswordException().also { it.initCause(ex) }
        }
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

    private fun mapTwilioTrialError(t: Throwable): Throwable =
        com.equipseva.app.core.auth.mapTwilioTrialError(t)

    override suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.PHONE_CHANGE,
            phone = phone,
            token = token,
        )
    }

    override suspend fun updateEmail(currentPassword: String, newEmail: String): Result<Unit> = runCatching {
        // Re-auth gate — same rationale as updatePassword. Without proof of
        // current credentials an attacker with an unlocked device could
        // redirect account recovery to an address they control.
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
            this.email = newEmail
        }
        Unit
    }

    override suspend fun updateEmailDuringKyc(newEmail: String): Result<Unit> = runCatching {
        client.auth.updateUser {
            this.email = newEmail
        }
        Unit
    }

    override suspend fun signOut(): Result<Unit> = runCatching {
        // Default scope is GLOBAL which makes a network call to revoke
        // the server-side session. A network failure used to leave the
        // user in a half-signed-out state: device-resident user data
        // was wiped (outbox / FCM token / prefs in ProfileViewModel)
        // but the local session token persisted, so on next app launch
        // Supabase auth-kt restored the previous session and the user
        // was magically "signed back in" against an empty outbox. The
        // sequence here: try the GLOBAL revoke first; if it fails (which
        // it will on offline / 5xx) fall back to LOCAL so the session
        // is at least cleared on this device. Re-raise the original
        // failure so the caller still surfaces an error toast — the
        // local clear is silent defense-in-depth, not a swallow.
        try {
            client.auth.signOut(SignOutScope.GLOBAL)
        } catch (globalErr: Throwable) {
            // Don't run the LOCAL fallback on coroutine cancellation —
            // the caller is going away, not asking us to recover.
            if (globalErr is kotlinx.coroutines.CancellationException) throw globalErr
            runCatching { client.auth.signOut(SignOutScope.LOCAL) }
            throw globalErr
        }
    }

    override suspend fun refreshSession(): Result<Unit> = runCatching {
        client.auth.refreshCurrentSession()
    }
}

/**
 * Twilio trial accounts reject sends to non-verified numbers with
 * error 21608. Map that to a clearer message; preserve the original
 * cause for logs.
 *
 * Trial-mode detection looks for three signals (any one trips it):
 *   * literal Twilio error code `21608` anywhere in the message chain
 *   * the words `unverified` + `twilio` together (catches reworded
 *     Supabase wrappers)
 *   * the words `trial` + `verified` together (catches the human-
 *     readable Twilio dashboard copy)
 *
 * Returns the original throwable when no trial signal is found so
 * Crashlytics still sees the underlying exception class + stack.
 */
internal fun mapTwilioTrialError(t: Throwable): Throwable {
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
