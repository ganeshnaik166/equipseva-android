package com.equipseva.app.core.storage

/**
 * Pure policy object for which MIME types / byte-lengths each Supabase Storage bucket will
 * accept from the Android client. The Supabase bucket itself should also enforce the same
 * via `allowed_mime_types` / `file_size_limit`, but we validate on-device so users get a
 * typed error before the upload roundtrip.
 */
object UploadValidator {

    private val imageMimeTypes = setOf("image/jpeg", "image/png", "image/webp")
    private val pdfMimeTypes = setOf("application/pdf")

    data class Policy(
        val allowedMimeTypes: Set<String>,
        val maxBytes: Long,
    )

    private val policies: Map<String, Policy> = mapOf(
        StorageRepository.Buckets.REPAIR_PHOTOS to Policy(imageMimeTypes, 10L * 1024 * 1024),
        StorageRepository.Buckets.CATALOG_IMAGES to Policy(imageMimeTypes, 10L * 1024 * 1024),
        StorageRepository.Buckets.KYC_DOCS to Policy(imageMimeTypes + pdfMimeTypes, 15L * 1024 * 1024),
        StorageRepository.Buckets.INVOICES to Policy(pdfMimeTypes, 10L * 1024 * 1024),
    )

    fun validate(bucket: String, contentType: String?, size: Long): Result<Policy> {
        val policy = policies[bucket]
            ?: return Result.failure(UploadError.UnknownBucket(bucket))
        val normalized = contentType?.substringBefore(';')?.trim()?.lowercase()
        if (normalized.isNullOrEmpty() || normalized !in policy.allowedMimeTypes) {
            return Result.failure(UploadError.MimeNotAllowed(bucket, normalized, policy.allowedMimeTypes))
        }
        if (size <= 0 || size > policy.maxBytes) {
            return Result.failure(UploadError.TooLarge(bucket, size, policy.maxBytes))
        }
        return Result.success(policy)
    }

    fun isImage(contentType: String?): Boolean {
        val normalized = contentType?.substringBefore(';')?.trim()?.lowercase()
        return normalized in imageMimeTypes
    }
}

sealed class UploadError(message: String) : RuntimeException(message) {
    class UnknownBucket(val bucket: String) : UploadError("unknown bucket: $bucket")
    class MimeNotAllowed(
        val bucket: String,
        val received: String?,
        val allowed: Set<String>,
    ) : UploadError("mime '$received' not allowed for $bucket (allowed=${allowed.joinToString()})")
    class TooLarge(val bucket: String, val size: Long, val max: Long) :
        UploadError("upload size $size exceeds $max bytes for $bucket")
}
