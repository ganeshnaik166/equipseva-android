package com.equipseva.app.core.sync.handlers

import kotlinx.serialization.Serializable

/**
 * Outbox payload for a queued photo upload.
 *
 * A photo upload is two writes the client has to coordinate — storage PUT +
 * DB row patch (e.g. appending the URL to `repair_jobs.before_photos`). Both
 * are deferred through the outbox so a weak-network capture doesn't silently
 * drop on the floor.
 *
 * `localFilePath` points to a copy we stash under the app's files dir at
 * enqueue time. Using the picker URI directly would race document providers
 * that revoke read permission when the originating screen is destroyed. The
 * handler deletes this file on success so we don't leak capture bytes.
 *
 * `uploaderUserId` is the owner-gate: on drain we re-check `auth.uid()`
 * matches this id and refuse to upload under a different signed-in user
 * (shared device / sign-out-in-between scenario).
 *
 * `contextType` discriminates which DB column to append the resulting URL
 * onto. Unknown values upload the bytes and skip the DB patch — a future
 * feature can start emitting a new `contextType` without shipping a handler
 * update in the same release.
 */
@Serializable
data class PhotoUploadPayload(
    val bucket: String,
    val objectPath: String,
    val localFilePath: String,
    val mimeType: String,
    val contextType: String,
    val contextId: String,
    val uploaderUserId: String,
) {
    companion object {
        /** Append URL to `repair_jobs.before_photos` where `id = contextId`. */
        const val CONTEXT_REPAIR_JOB_BEFORE = "repair_job_before"

        /** Append URL to `repair_jobs.after_photos` where `id = contextId`. */
        const val CONTEXT_REPAIR_JOB_AFTER = "repair_job_after"

        /** Append URL to `repair_jobs.issue_photos` where `id = contextId`. */
        const val CONTEXT_REPAIR_JOB_ISSUE = "repair_job_issue"

        /** KYC doc — upload only; the KYC save flow persists the path. */
        const val CONTEXT_KYC_DOC = "kyc_doc"

        /** Hard cap matching the bucket policy (KYC allows 15 MB, photos 10 MB). */
        const val MAX_FILE_SIZE_BYTES: Long = 15L * 1024 * 1024
    }
}
