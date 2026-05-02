package com.equipseva.app.core.util

import com.equipseva.app.BuildConfig

object BuildConfigValues {
    val supabaseUrl: String = BuildConfig.SUPABASE_URL
    val supabaseAnonKey: String = BuildConfig.SUPABASE_ANON_KEY
    val sentryDsn: String = BuildConfig.SENTRY_DSN
    // razorpayKey dropped for v1 (payments deferred to v2).
    val googleWebClientId: String = BuildConfig.GOOGLE_WEB_CLIENT_ID

    val hasSupabaseConfig: Boolean
        get() = supabaseUrl.isNotBlank() && supabaseAnonKey.isNotBlank()

    val hasGoogleSignInConfig: Boolean
        get() = googleWebClientId.isNotBlank()
}
