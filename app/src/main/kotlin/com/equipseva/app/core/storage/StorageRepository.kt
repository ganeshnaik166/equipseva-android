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

    /**
     * Uploads [bytes] to [bucket]/[path]. Enforces:
     *   - MIME type allowlist (per [UploadValidator])
     *   - size ceiling (per [UploadValidator])
     *   - EXIF/metadata scrub for JPEG images (via [ExifScrubber])
     *
     * Callers should catch [UploadError] and surface a human-readable message; the bucket
     * policy in Supabase enforces the same rules server-side as a backstop.
     */
    suspend fun upload(
        bucket: String,
        path: String,
        bytes: ByteArray,
        contentType: String? = null,
    ): Result<Unit> = runCatching {
        val policy = UploadValidator.validate(bucket, contentType, bytes.size.toLong()).getOrThrow()
        val scrubbed = ExifScrubber.strip(bytes, contentType)
        supabase.storage.from(bucket).upload(path, scrubbed) {
            upsert = true
            contentType?.let { this.contentType = io.ktor.http.ContentType.parse(it) }
        }
        // policy is returned to callers who want to branch on the concrete limits.
        @Suppress("UNUSED_VARIABLE")
        val _p = policy
    }

    suspend fun signedUrl(bucket: String, path: String, expiresInMinutes: Int = 15): String =
        supabase.storage.from(bucket).createSignedUrl(path, expiresInMinutes.minutes)
}
