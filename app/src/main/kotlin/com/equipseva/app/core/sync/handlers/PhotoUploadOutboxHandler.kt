package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.OutboxKindHandler
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import javax.inject.Inject

/**
 * Drains queued photo uploads. Each entry is two coupled writes: upload the
 * stashed local file to [StorageRepository] and (when the payload names a
 * known DB context) append the resulting public URL to the matching array
 * column on `repair_jobs`.
 *
 * Owner gate: `auth.uid()` must equal `payload.uploaderUserId`. Outbox rows
 * outlive sign-out/sign-in, so on a shared device user B could otherwise
 * drain user A's queued upload — best case RLS rejects it, worst case the
 * photo ends up on B's record. On mismatch we [Outcome.GiveUp] and drop; no
 * signed-in user ⇒ [Outcome.Retry] on the next flush.
 *
 * Permanent fail cases ([Outcome.GiveUp]):
 *  - Malformed payload JSON.
 *  - Missing / empty / oversized local file (> [PhotoUploadPayload.MAX_FILE_SIZE_BYTES]).
 *  - Owner mismatch.
 *
 * Transient fail cases ([Outcome.Retry]):
 *  - No auth session yet (user is signed out right now).
 *  - IO/network error talking to Supabase Storage or Postgrest.
 *
 * Success path cleans up the stashed local file so we don't leak capture
 * bytes in app storage. The DB patch is best-effort: if appending the URL
 * fails (e.g. RLS, missing column on a stale schema), the storage upload
 * still counts as success — we log and move on rather than burn retries
 * hammering the same 403.
 */
class PhotoUploadOutboxHandler @Inject constructor(
    private val storage: StorageRepository,
    private val supabase: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<PhotoUploadPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        // Owner gate — see class doc.
        val currentUid = supabase.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring photo upload"),
            )
        if (currentUid != payload.uploaderUserId) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Uploader mismatch: queued as ${payload.uploaderUserId}, current auth is $currentUid",
            )
        }

        val file = File(payload.localFilePath)
        if (!file.exists() || !file.isFile) {
            return OutboxKindHandler.Outcome.GiveUp("Local file missing: ${payload.localFilePath}")
        }
        val size = file.length()
        if (size <= 0L) {
            return OutboxKindHandler.Outcome.GiveUp("Local file empty: ${payload.localFilePath}")
        }
        if (size > PhotoUploadPayload.MAX_FILE_SIZE_BYTES) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Local file too large: $size > ${PhotoUploadPayload.MAX_FILE_SIZE_BYTES}",
            )
        }

        val bytes = runCatching { file.readBytes() }
            .getOrElse {
                return if (it is IOException) {
                    OutboxKindHandler.Outcome.Retry(it)
                } else {
                    OutboxKindHandler.Outcome.GiveUp("Read failed: ${it.message}")
                }
            }

        val uploadResult = storage.upload(
            bucket = payload.bucket,
            path = payload.objectPath,
            bytes = bytes,
            contentType = payload.mimeType,
        )
        val uploadError = uploadResult.exceptionOrNull()
        if (uploadError != null) {
            return if (isTransient(uploadError)) {
                OutboxKindHandler.Outcome.Retry(uploadError)
            } else {
                // Validator (mime/size/path) → permanent; don't clog the queue.
                OutboxKindHandler.Outcome.GiveUp("Upload rejected: ${uploadError.message}")
            }
        }

        // Best-effort: patch the owning row with a URL reference. A signed URL
        // is used instead of a public URL because our photo buckets may be
        // private — the stored string is what the read side will hand back to
        // storage.createSignedUrl on render anyway, so we just persist the
        // object path and let the read side mint fresh signed URLs.
        appendUrlToContext(
            contextType = payload.contextType,
            contextId = payload.contextId,
            objectPath = payload.objectPath,
        )

        // Clean up the stashed file — on failure just log; the outer worker
        // has no rollback for the remote upload and we don't want to keep
        // retrying a successful upload forever.
        runCatching { file.delete() }.onFailure {
            Log.w(TAG, "Failed to delete stashed file ${payload.localFilePath}", it)
        }

        return OutboxKindHandler.Outcome.Success
    }

    /**
     * Append [objectPath] onto the array column implied by [contextType] for
     * the row [contextId] on `repair_jobs`. Unknown [contextType] values
     * (including [PhotoUploadPayload.CONTEXT_KYC_DOC]) are treated as
     * upload-only — the caller owns persistence of the path.
     *
     * Uses read-modify-write: RLS would reject an engineer patching a job
     * they don't belong to anyway, so the race window here is "same user
     * uploads two photos at the same time". Worst case we drop one entry
     * of the two; the photo bytes are still in storage and a future
     * reconcile can repair. Acceptable for v1.
     */
    private suspend fun appendUrlToContext(
        contextType: String,
        contextId: String,
        objectPath: String,
    ) {
        val column = when (contextType) {
            PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE -> "before_photos"
            PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER -> "after_photos"
            PhotoUploadPayload.CONTEXT_REPAIR_JOB_ISSUE -> "issue_photos"
            else -> return
        }
        if (contextId.isBlank()) return

        runCatching {
            val current = supabase.from("repair_jobs").select {
                filter { eq("id", contextId) }
                limit(count = 1)
            }.decodeList<RepairJobPhotosRow>().firstOrNull()

            val existing = when (column) {
                "before_photos" -> current?.before_photos
                "after_photos" -> current?.after_photos
                "issue_photos" -> current?.issue_photos
                else -> null
            }.orEmpty()
            if (objectPath in existing) return@runCatching // idempotent

            val next = existing + objectPath
            val patch = when (column) {
                "before_photos" -> RepairJobPhotosPatch(before_photos = next)
                "after_photos" -> RepairJobPhotosPatch(after_photos = next)
                "issue_photos" -> RepairJobPhotosPatch(issue_photos = next)
                else -> return@runCatching
            }
            supabase.from("repair_jobs").update(patch) {
                filter { eq("id", contextId) }
            }
        }.onFailure {
            // Deliberately swallow — see class doc. The storage upload is the
            // load-bearing half of this operation; the URL append is nice-to-have.
            Log.w(TAG, "Append-URL failed for $contextType/$contextId", it)
        }
    }

    private fun isTransient(error: Throwable): Boolean {
        // Validator errors (com.equipseva.app.core.storage.UploadError) are
        // permanent — bad mime/size/path won't fix itself. Everything else
        // (IOException, Ktor HTTP exceptions, RLS 500s from transient DB hic-
        // cups) gets one more flush attempt before the worker poisons it.
        return error !is com.equipseva.app.core.storage.UploadError
    }

    @Serializable
    @Suppress("ConstructorParameterNaming", "ConstructorParameterNaming")
    private data class RepairJobPhotosRow(
        val before_photos: List<String>? = null,
        val after_photos: List<String>? = null,
        val issue_photos: List<String>? = null,
    )

    @Serializable
    @Suppress("ConstructorParameterNaming")
    private data class RepairJobPhotosPatch(
        val before_photos: List<String>? = null,
        val after_photos: List<String>? = null,
        val issue_photos: List<String>? = null,
    )

    private companion object {
        const val TAG = "PhotoUploadOutbox"
    }
}
