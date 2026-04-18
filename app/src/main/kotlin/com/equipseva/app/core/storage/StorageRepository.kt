package com.equipseva.app.core.storage

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.storage.storage
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.time.Duration.Companion.minutes

@Singleton
class StorageRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {
    object Buckets {
        const val REPAIR_PHOTOS = "repair-photos"
        const val INVOICES = "invoices"
        const val KYC_DOCS = "kyc-docs"
        const val CATALOG_IMAGES = "catalog-images"
    }

    suspend fun upload(bucket: String, path: String, bytes: ByteArray, contentType: String? = null) {
        supabase.storage.from(bucket).upload(path, bytes) {
            upsert = true
            contentType?.let { this.contentType = io.ktor.http.ContentType.parse(it) }
        }
    }

    suspend fun signedUrl(bucket: String, path: String, expiresInMinutes: Int = 15): String =
        supabase.storage.from(bucket).createSignedUrl(path, expiresInMinutes.minutes)
}
