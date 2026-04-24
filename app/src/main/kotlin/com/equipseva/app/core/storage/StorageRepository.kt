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
     *   - path safety: rejects "..", absolute paths, control chars, backslashes
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
        validatePath(path).getOrThrow()
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

    suspend fun signedUrl(bucket: String, path: String, expiresInMinutes: Int = 15): String {
        validatePath(path).getOrThrow()
        return supabase.storage.from(bucket).createSignedUrl(path, expiresInMinutes.minutes)
    }

    // Defense-in-depth path guard. Callers (e.g. KycViewModel.timestampedName) already
    // sanitize the file-name segment, but we re-check at the repository so a future
    // caller can't accidentally route user input straight into an object key. Supabase
    // Storage object keys are S3-style, but `storage.foldername()`-based RLS policies
    // typically key on the first segment — a leading slash or `..` could collapse the
    // owner prefix and route writes to another user's folder.
    private fun validatePath(path: String): Result<Unit> {
        if (path.isBlank()) return Result.failure(UploadError.InvalidPath(path, "empty"))
        if (path.startsWith('/')) return Result.failure(UploadError.InvalidPath(path, "absolute"))
        if (path.contains('\\')) return Result.failure(UploadError.InvalidPath(path, "backslash"))
        if (path.any { it.code < 0x20 || it.code == 0x7F }) {
            return Result.failure(UploadError.InvalidPath(path, "control char"))
        }
        val segments = path.split('/')
        if (segments.any { it == ".." || it == "." }) {
            return Result.failure(UploadError.InvalidPath(path, "traversal segment"))
        }
        return Result.success(Unit)
    }
}
