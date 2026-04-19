package com.equipseva.app.core.supabase

import com.equipseva.app.core.util.BuildConfigValues
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object SupabaseModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient = createSupabaseClient(
        supabaseUrl = BuildConfigValues.supabaseUrl,
        supabaseKey = BuildConfigValues.supabaseAnonKey,
    ) {
        // Coerce `null` wire values into Kotlin defaults when the field has one.
        // Supabase columns declared NOT NULL in newer migrations can still return
        // null for rows inserted before the constraint — without coercion the whole
        // decode crashes. `ignoreUnknownKeys` keeps us forward-compatible with new
        // columns added on the backend without an app update.
        defaultSerializer = KotlinXSerializer(
            Json {
                coerceInputValues = true
                ignoreUnknownKeys = true
                isLenient = true
            },
        )
        install(Auth)
        install(Postgrest)
        install(Realtime)
        install(Storage)
        install(Functions)
    }
}
