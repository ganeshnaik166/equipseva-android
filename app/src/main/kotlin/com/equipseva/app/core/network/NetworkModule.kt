package com.equipseva.app.core.network

import com.equipseva.app.BuildConfig
import com.equipseva.app.core.network.interceptors.AuthInterceptor
import com.equipseva.app.core.util.BuildConfigValues
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        encodeDefaults = true
    }

    @Provides
    @Singleton
    fun provideOkHttp(authInterceptor: AuthInterceptor): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            // Debug builds log headers + method + URL; release builds log nothing. Bodies
            // are deliberately NOT logged — the Supabase SDK carries JWTs in request bodies
            // for RPC calls and we don't want those in logcat even on developer machines.
            level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.HEADERS else HttpLoggingInterceptor.Level.NONE
            // Scrub the bearer token from the header dump even in debug.
            redactHeader("Authorization")
            redactHeader("apikey")
            redactHeader("Cookie")
            redactHeader("Set-Cookie")
        }
        return OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient, json: Json): Retrofit {
        // Defaults to Supabase REST host; per-feature service interfaces can override @Url.
        val baseUrl = BuildConfigValues.supabaseUrl.takeIf { it.isNotBlank() }
            ?.removeSuffix("/")?.plus("/rest/v1/")
            ?: "https://placeholder.invalid/"
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
    }
}
