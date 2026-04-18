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
        override val userMessage = "Email or password is incorrect."
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
    data object Cancelled : AuthError {
        override val userMessage = "Sign-in cancelled."
    }
    data class Unknown(override val userMessage: String) : AuthError
}

fun Throwable.toAuthError(): AuthError = when (this) {
    is AuthRestException -> classifyAuthRest(this)
    is RestException -> AuthError.Unknown(message ?: "Authentication failed.")
    is HttpRequestException, is IOException -> AuthError.Network
    else -> AuthError.Unknown(message ?: "Something went wrong.")
}

private fun classifyAuthRest(e: AuthRestException): AuthError {
    val msg = (e.message ?: "").lowercase()
    val code = e.error.lowercase()
    return when {
        code.contains("invalid_credentials") || msg.contains("invalid login credentials") -> AuthError.InvalidCredentials
        code.contains("email_not_confirmed") || msg.contains("email not confirmed") -> AuthError.EmailNotConfirmed
        code.contains("user_already_exists") || msg.contains("already registered") -> AuthError.UserAlreadyExists
        code.contains("otp_expired") || msg.contains("token has expired") || msg.contains("invalid otp") || msg.contains("invalid token") -> AuthError.OtpExpiredOrInvalid
        code.contains("over_email_send_rate_limit") || code.contains("over_request_rate_limit") || msg.contains("rate limit") -> AuthError.RateLimited
        else -> AuthError.Unknown(e.message ?: "Authentication failed.")
    }
}
