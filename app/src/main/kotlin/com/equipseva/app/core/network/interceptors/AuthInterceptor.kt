package com.equipseva.app.core.network.interceptors

import com.equipseva.app.core.util.BuildConfigValues
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthInterceptor @Inject constructor(
    private val supabase: SupabaseClient,
) : Interceptor {

    // Host-gate: only attach the Supabase JWT to requests for the configured Supabase
    // project. Without this, sharing the OkHttp client with Coil or any third-party
    // Retrofit @Url leaks the user's bearer token to that host. Parsed once.
    private val supabaseHost: String? by lazy {
        BuildConfigValues.supabaseUrl
            .takeIf { it.isNotBlank() }
            ?.toHttpUrlOrNull()
            ?.host
    }

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val targetHost = request.url.host
        val expected = supabaseHost
        if (expected == null || targetHost != expected) {
            return chain.proceed(request)
        }
        val token = runCatching { supabase.auth.currentAccessTokenOrNull() }
            .onFailure { android.util.Log.w("AuthInterceptor", "currentAccessTokenOrNull threw: ${it.message}") }
            .getOrNull()
        val out = if (!token.isNullOrBlank()) {
            request.newBuilder().header("Authorization", "Bearer $token").build()
        } else {
            request
        }
        return chain.proceed(out)
    }
}
