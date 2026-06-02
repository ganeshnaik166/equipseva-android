package com.equipseva.app.core.auth

import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import java.io.IOException

/**
 * User-facing classification of auth failures. Maps the noise of Supabase exceptions into
 * a small set of cases the UI can handle predictably.
 */
sealed interface AuthError {
    val userMessage: String

    data object InvalidCredentials : AuthError {
        // Supabase masks the difference between "wrong password" and
        // "no such email" to prevent user enumeration. Surface both
        // recovery paths so a user with a typo in their email doesn't
        // assume the platform forgot them and create a duplicate
        // account, and a user who forgot their password still sees
        // the reset path inline.
        override val userMessage = "Email or password is wrong. Try Forgot password, or sign up if you don't have an account."
    }
    data object EmailNotConfirmed : AuthError {
        override val userMessage = "Confirm your email before signing in."
    }
    data object UserAlreadyExists : AuthError {
        override val userMessage = "An account with this email already exists. Try signing in."
    }
    data object OtpExpiredOrInvalid : AuthError {
        override val userMessage = "That code is invalid or expired. Request a new one."
    }
    data object RateLimited : AuthError {
        override val userMessage = "Too many attempts. Please wait a minute and try again."
    }
    data object Network : AuthError {
        override val userMessage = "Network problem. Check your connection and retry."
    }
    data class Unknown(override val userMessage: String) : AuthError
}

fun Throwable.toAuthError(): AuthError = when (this) {
    is AuthRestException -> classifyAuthRest(this)
    is RestException -> AuthError.Unknown(message ?: "Authentication failed.")
    is HttpRequestException, is IOException -> AuthError.Network
    else -> AuthError.Unknown(message ?: "Something went wrong.")
}

private fun classifyAuthRest(e: AuthRestException): AuthError =
    classifyAuthRestCodes(code = e.error, message = e.message)

/**
 * Pure classifier — splits the auth-error code + message into the
 * known [AuthError] cases. Kept top-level so unit tests don't have to
 * construct a real [AuthRestException] (which transitively pulls in
 * the Supabase Auth SDK + a live HTTP session).
 */
internal fun classifyAuthRestCodes(code: String?, message: String?): AuthError {
    val msg = (message ?: "").lowercase()
    val codeLower = (code ?: "").lowercase()
    return when {
        codeLower.contains("invalid_credentials") || msg.contains("invalid login credentials") -> AuthError.InvalidCredentials
        codeLower.contains("email_not_confirmed") || msg.contains("email not confirmed") -> AuthError.EmailNotConfirmed
        codeLower.contains("user_already_exists") || msg.contains("already registered") -> AuthError.UserAlreadyExists
        codeLower.contains("otp_expired") || msg.contains("token has expired") || msg.contains("invalid otp") || msg.contains("invalid token") -> AuthError.OtpExpiredOrInvalid
        codeLower.contains("over_email_send_rate_limit") || codeLower.contains("over_request_rate_limit") || msg.contains("rate limit") -> AuthError.RateLimited
        else -> AuthError.Unknown(message ?: "Authentication failed.")
    }
}
