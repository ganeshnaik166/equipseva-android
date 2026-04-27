package com.equipseva.app.core.sync.handlers

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Writes photo bytes to a known location under the app's private files dir
 * and hands the outbox a stable path it can read back at drain time.
 *
 * Queueing the raw URI from a picker is fragile — document providers revoke
 * read permission when the originating activity/screen is torn down, so by
 * the time the worker runs the URI is dead. Copying once at enqueue time
 * into `filesDir/photo-outbox/` gives us a path owned by the app process,
 * readable from the worker no matter when it runs (even after app restart),
 * and trivially deleted on success.
 *
 * The stash dir survives uninstall via app uninstall alone; it will NOT be
 * backed up to Google Drive (we don't want in-flight KYC docs sync'd off
 * device). That's already the default for `context.filesDir` because
 * `allowBackup="false"` is set on the manifest; we just put files here.
 */
interface PhotoUploadStash {
    /**
     * Wipes every file in the stash dir. Called on sign-out so the next
     * user can't accidentally drain the previous user's queued photos
     * (the outbox handler also re-verifies auth.uid, but the bytes
     * themselves shouldn't sit on the device after the owning session
     * ends).
     */
    suspend fun clearAll()

    /**
     * Copies [bytes] into a durable stash dir under a unique filename, builds
     * a [PhotoUploadPayload], and enqueues it for the outbox worker to drain.
     *
     * @param bucket Supabase Storage bucket (e.g. "repair-photos", "kyc-docs").
     * @param objectPath Target object key in the bucket. Must already include
     *   any user-folder prefix required by RLS (e.g. "<uid>/before/foo.jpg").
     * @param bytes Raw image/pdf bytes from the picker.
     * @param mimeType Caller-supplied MIME (same value passed to StorageRepository.upload).
     * @param contextType One of [PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE] etc.
     * @param contextId Row id in the target table (or empty for upload-only contexts).
     * @param uploaderUserId auth.uid of the user who captured this photo; the
     *   handler owner-gates against this on drain.
     */
    suspend fun enqueue(
        bucket: String,
        objectPath: String,
        bytes: ByteArray,
        mimeType: String,
        contextType: String,
        contextId: String,
        uploaderUserId: String,
    )

    companion object {
        const val STASH_DIR_NAME = "photo-outbox"
    }
}

@Singleton
class DefaultPhotoUploadStash @Inject constructor(
    @ApplicationContext private val context: Context,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val json: Json,
) : PhotoUploadStash {
    private val stashDir: File by lazy {
        File(context.filesDir, PhotoUploadStash.STASH_DIR_NAME).apply { if (!exists()) mkdirs() }
    }

    override suspend fun enqueue(
        bucket: String,
        objectPath: String,
        bytes: ByteArray,
        mimeType: String,
        contextType: String,
        contextId: String,
        uploaderUserId: String,
    ) {
        require(uploaderUserId.isNotBlank()) { "uploaderUserId required for owner-gate" }
        require(bytes.isNotEmpty()) { "cannot enqueue empty file" }
        require(bytes.size.toLong() <= PhotoUploadPayload.MAX_FILE_SIZE_BYTES) {
            "photo ${bytes.size}B exceeds cap ${PhotoUploadPayload.MAX_FILE_SIZE_BYTES}"
        }

        val filename = "${System.currentTimeMillis()}-${objectPath.substringAfterLast('/').ifBlank { "photo" }}"
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
        val local = File(stashDir, filename).apply { writeBytes(bytes) }

        val payload = PhotoUploadPayload(
            bucket = bucket,
            objectPath = objectPath,
            localFilePath = local.absolutePath,
            mimeType = mimeType,
            contextType = contextType,
            contextId = contextId,
            uploaderUserId = uploaderUserId,
        )
        outboxEnqueuer.enqueue(OutboxKinds.PHOTO_UPLOAD, json.encodeToString(payload))
    }

    override suspend fun clearAll() {
        runCatching {
            stashDir.listFiles()?.forEach { file -> file.delete() }
        }
    }
}
