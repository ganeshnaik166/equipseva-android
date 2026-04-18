package com.equipseva.app.core.util

import com.equipseva.app.BuildConfig

object BuildConfigValues {
    val supabaseUrl: String = BuildConfig.SUPABASE_URL
    val supabaseAnonKey: String = BuildConfig.SUPABASE_ANON_KEY
    val sentryDsn: String = BuildConfig.SENTRY_DSN
    val razorpayKey: String = BuildConfig.RAZORPAY_KEY
    val googleWebClientId: String = BuildConfig.GOOGLE_WEB_CLIENT_ID

    val hasSupabaseConfig: Boolean
        get() = supabaseUrl.isNotBlank() && supabaseAnonKey.isNotBlank()

    val hasGoogleSignInConfig: Boolean
        get() = googleWebClientId.isNotBlank()
}
