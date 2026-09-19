package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
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
 * Every terminal path — success, give-up and the worker's poison drop via
 * [onDropped] — deletes the stashed file. The stash holds KYC documents as
 * well as repair photos, so a path that frees nothing leaves an Aadhaar or PAN
 * scan in `filesDir` until the user next signs out, which is exactly what this
 * class exists to avoid.
 *
 * The DB patch is best-effort: if appending the URL fails (e.g. RLS, missing
 * column on a stale schema), the storage upload still counts as success — we
 * log and move on rather than burn retries hammering the same 403.
 */
class PhotoUploadOutboxHandler @Inject constructor(
    private val storage: StorageRepository,
    private val supabase: SupabaseClient,
    private val json: Json,
    private val outbox: OutboxEnqueuer,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<PhotoUploadPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        // Owner gate — see class doc.
        val currentUid = supabase.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring photo upload"),
                countsAgainstBudget = false,
            )
        if (currentUid != payload.uploaderUserId) {
            return dropWithCleanup(
                payload,
                "Uploader mismatch: queued as ${payload.uploaderUserId}, current auth is $currentUid",
            )
        }

        val file = File(payload.localFilePath)
        if (!file.exists() || !file.isFile) {
            return OutboxKindHandler.Outcome.GiveUp("Local file missing: ${payload.localFilePath}")
        }
        val size = file.length()
        if (size <= 0L) {
            return dropWithCleanup(payload, "Local file empty: ${payload.localFilePath}")
        }
        if (size > PhotoUploadPayload.MAX_FILE_SIZE_BYTES) {
            return dropWithCleanup(
                payload,
                "Local file too large: $size > ${PhotoUploadPayload.MAX_FILE_SIZE_BYTES}",
            )
        }

        val bytes = runCatching { file.readBytes() }
            .getOrElse {
                return if (it is IOException) {
                    OutboxKindHandler.Outcome.Retry(it)
                } else {
                    dropWithCleanup(payload, "Read failed: ${it.message}")
                }
            }

        // Bound the upload. The supabase-kt client has no explicit timeout on
        // storage.upload; a hung TLS connection on a flaky network would
        // otherwise block this worker until the entry is poison-dropped. The
        // budget scales with the file because the stash cap is 15 MB (the KYC
        // bucket) — a fixed one-minute cap timed out every single attempt for
        // a large PDF on a slow link, so re-attaching reproduced the failure
        // forever. See [uploadTimeoutFor].
        val uploadResult = try {
            withTimeout(uploadTimeoutFor(size)) {
                storage.upload(
                    bucket = payload.bucket,
                    path = payload.objectPath,
                    bytes = bytes,
                    contentType = payload.mimeType,
                )
            }
        } catch (timeout: TimeoutCancellationException) {
            return OutboxKindHandler.Outcome.Retry(timeout)
        }
        val uploadError = uploadResult.exceptionOrNull()
        if (uploadError != null) {
            // Funnels UploadError → GiveUp, 4xx Supabase errors → GiveUp,
            // everything network-shaped → Retry. Keeps the validator
            // skip behaviour identical to the prior local isTransient().
            val outcome = classifyOutboxError(uploadError)
            return if (outcome is OutboxKindHandler.Outcome.GiveUp) {
                dropWithCleanup(payload, outcome.reason)
            } else {
                outcome
            }
        }
        val receipt = uploadResult.getOrThrow()

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

        // round3820 — repair before/after photos are §65B evidence. Hand the
        // stored bytes' sha256 + size (from the receipt — the post-scrub
        // object, the only hash a later download can match) to a SEPARATE
        // outbox kind so registration retries never re-upload the photo and
        // a registration failure never masquerades as an upload failure.
        //
        // Queued before the stashed file is deleted, and nothing here is
        // swallowed: a cancellation (sign-out, WorkManager stop) used to be
        // absorbed, the file deleted and Success reported, which put the photo
        // on the job with no ledger row at all and no record that it was
        // missing. Re-uploading is cheap by comparison — the storage write
        // upserts the same object path.
        val evidence = EvidenceRegisterPayload.forUploadedPhoto(payload, receipt, currentUid)
        if (evidence != null) {
            try {
                outbox.enqueue(
                    kind = com.equipseva.app.core.sync.OutboxKinds.EVIDENCE_REGISTER,
                    payloadJson = json.encodeToString(EvidenceRegisterPayload.serializer(), evidence),
                )
            } catch (ce: CancellationException) {
                throw ce
            } catch (t: Throwable) {
                Log.w(TAG, "Could not queue evidence registration for ${payload.objectPath}", t)
                return OutboxKindHandler.Outcome.Retry(t)
            }
        }

        // Clean up the stashed file — on failure just log; the outer worker
        // has no rollback for the remote upload and we don't want to keep
        // retrying a successful upload forever.
        deleteStash(payload.localFilePath)

        return OutboxKindHandler.Outcome.Success
    }

    /**
     * The worker's poison drop deletes the row that is the only reference to
     * the stashed file, so the bytes have to go with it.
     */
    override suspend fun onDropped(entry: OutboxEntryEntity) {
        val payload = runCatching { json.decodeFromString<PhotoUploadPayload>(entry.payload) }
            .getOrNull() ?: return
        deleteStash(payload.localFilePath)
    }

    /**
     * A permanent refusal for an entry whose stashed bytes nothing will ever
     * read again. Dropping the row without this leaks the file: capture bytes
     * for a repair photo, an identity document for a KYC upload.
     */
    private fun dropWithCleanup(
        payload: PhotoUploadPayload,
        reason: String,
    ): OutboxKindHandler.Outcome {
        deleteStash(payload.localFilePath)
        return OutboxKindHandler.Outcome.GiveUp(reason)
    }

    private fun deleteStash(localFilePath: String) {
        runCatching { File(localFilePath).delete() }.onFailure {
            Log.w(TAG, "Failed to delete stashed file $localFilePath", it)
        }
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

        // Round 436 — explicit try/catch so CancellationException re-throws
        // when WorkManager cancels the parent worker. runCatching would
        // swallow it and the appendUrl flow would log "Append-URL failed:
        // StandaloneCoroutine was cancelled" as if it were a real error.
        try {
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
            if (objectPath in existing) return // idempotent

            val next = existing + objectPath
            val patch = when (column) {
                "before_photos" -> RepairJobPhotosPatch(before_photos = next)
                "after_photos" -> RepairJobPhotosPatch(after_photos = next)
                "issue_photos" -> RepairJobPhotosPatch(issue_photos = next)
                else -> return
            }
            supabase.from("repair_jobs").update(patch) {
                filter { eq("id", contextId) }
            }
        } catch (ce: CancellationException) {
            throw ce
        } catch (t: Throwable) {
            // Deliberately swallow — see class doc. The storage upload is the
            // load-bearing half of this operation; the URL append is nice-to-have.
            Log.w(TAG, "Append-URL failed for $contextType/$contextId", t)
        }
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

/** Floor for any upload, sized for a handshake plus a small file on a weak link. */
private const val UPLOAD_TIMEOUT_BASE_MS = 30_000L

/** Added per megabyte — roughly a 2G-grade transfer rate with margin. */
private const val UPLOAD_TIMEOUT_PER_MB_MS = 20_000L

/**
 * Ceiling, kept well inside WorkManager's 10-minute execution budget so the
 * rest of the batch still gets a turn before the runtime stops the worker.
 */
private const val UPLOAD_TIMEOUT_CEILING_MS = 420_000L

private const val BYTES_PER_MB = 1024L * 1024L

/** Guards the arithmetic against a nonsense size; the stash caps at 15 MB. */
private const val UPLOAD_TIMEOUT_MAX_SCALED_MB = 64L

/**
 * Upload timeout for a file of [sizeBytes], rounded up to whole megabytes.
 *
 * A single 60-second cap could not carry the stash's own 15 MB limit (the KYC
 * bucket's): a legitimately large identity document on a slow link timed out
 * on every attempt, restarted from byte zero — Supabase Storage uploads here
 * are not resumable — and was eventually dropped with "Couldn't upload a
 * photo". Re-attaching the same document reproduced it exactly, so the user
 * had no way through.
 */
internal fun uploadTimeoutFor(sizeBytes: Long): Long {
    // Clamped before the arithmetic, not after: rounding a size near
    // Long.MAX_VALUE up to whole megabytes overflows into a negative budget,
    // and a negative timeout fails the upload instantly on every attempt.
    val clamped = sizeBytes.coerceIn(0L, UPLOAD_TIMEOUT_MAX_SCALED_MB * BYTES_PER_MB)
    val megabytes = (clamped + BYTES_PER_MB - 1) / BYTES_PER_MB
    val budget = UPLOAD_TIMEOUT_BASE_MS + megabytes * UPLOAD_TIMEOUT_PER_MB_MS
    return budget.coerceAtMost(UPLOAD_TIMEOUT_CEILING_MS)
}
