package com.equipseva.app.core.data.openfda

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import javax.inject.Singleton

/**
 * Separate Retrofit instance for the public OpenFDA host. Reuses the shared
 * OkHttpClient — that client's AuthInterceptor is host-gated to the Supabase
 * project, so OpenFDA requests get no Authorization header. Reuses the shared
 * Json (ignoreUnknownKeys = true) so we don't have to hand-type every field.
 */
@Module
@InstallIn(SingletonComponent::class)
object OpenFdaModule {

    private const val BASE_URL = "https://api.fda.gov/"

    @Provides
    @Singleton
    fun provideOpenFdaApi(client: OkHttpClient, json: Json): OpenFdaApi {
        val retrofit = Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
        return retrofit.create(OpenFdaApi::class.java)
    }
}
