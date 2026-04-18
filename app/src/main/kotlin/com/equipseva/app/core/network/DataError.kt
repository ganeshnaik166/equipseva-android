package com.equipseva.app.core.network

import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import kotlinx.coroutines.CancellationException
import java.io.IOException

/**
 * Translates anything thrown by Supabase / Ktor / IO into a stable user-facing
 * message. ViewModels that aren't auth-specific should use this rather than
 * `toAuthError()`, which carries auth-flavoured copy.
 */
fun Throwable.toUserMessage(fallback: String = "Something went wrong. Please try again."): String {
    if (this is CancellationException) throw this
    return when (this) {
        is HttpRequestException, is IOException -> "Network problem. Check your connection and retry."
        is RestException -> message ?: fallback
        else -> message?.takeIf { it.isNotBlank() } ?: fallback
    }
}
