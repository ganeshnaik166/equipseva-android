package com.equipseva.app.core.network.interceptors

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthInterceptor @Inject constructor(
    private val supabase: SupabaseClient,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val token = runCatching { supabase.auth.currentAccessTokenOrNull() }.getOrNull()
        val request = chain.request().newBuilder().apply {
            if (!token.isNullOrBlank()) {
                header("Authorization", "Bearer $token")
            }
        }.build()
        return chain.proceed(request)
    }
}
