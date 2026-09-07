package com.equipseva.app.core.sync.handlers

import com.equipseva.app.core.storage.StorageRepository
import kotlinx.serialization.Serializable

/**
 * round3820 — outbox payload for [EvidenceRegisterOutboxHandler]: register an
 * already-uploaded repair photo in the §65B `evidence_ledger` through the
 * `register_evidence` RPC (round492). Everything the RPC needs is captured at
 * upload time from the [StorageRepository.UploadReceipt], so the handler never
 * re-reads or re-hashes a file.
 *
 * `evidenceKind` is one of the ledger's CHECK-listed kinds (`photo_before` /
 * `photo_after`); `sourceKind` is always `repair_job` here so the rows show up
 * in `evidence_for_repair_job()` next to the GPS check-in and DSR signatures.
 */
@Serializable
data class EvidenceRegisterPayload(
    val evidenceKind: String,
    val sourceKind: String,
    val sourceId: String,
    val contentSha256: String,
    val contentSizeBytes: Long,
    val storageUrl: String,
    val producerKind: String,
    val producerUserId: String,
    /** ISO-8601 instant the client attributes to the capture (see [CAPTURED_FROM_UPLOAD]). */
    val capturedAt: String,
    val mimeType: String,
) {
    companion object {
        const val SOURCE_REPAIR_JOB = "repair_job"
        const val KIND_PHOTO_BEFORE = "photo_before"
        const val KIND_PHOTO_AFTER = "photo_after"
        const val PRODUCER_ENGINEER = "engineer"

        /**
         * Metadata marker: the client has no trustworthy capture clock for a
         * gallery pick, so `capturedAt` is the upload instant. Stated in the
         * ledger row rather than dressed up as an EXIF time.
         */
        const val CAPTURED_FROM_UPLOAD = "upload_time"

        /**
         * Which ledger kind a photo-upload context maps to, or null when the
         * context is not job-execution evidence (issue photos are the
         * hospital's booking attachments; KYC docs are identity documents —
         * neither belongs in the repair-job evidence chain).
         */
        fun evidenceKindFor(contextType: String): String? = when (contextType) {
            PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE -> KIND_PHOTO_BEFORE
            PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER -> KIND_PHOTO_AFTER
            else -> null
        }

        /**
         * Builds the registration payload for a just-uploaded photo, or null
         * when the upload is not evidence. [nowIso] is injectable for tests.
         */
        fun forUploadedPhoto(
            upload: PhotoUploadPayload,
            receipt: StorageRepository.UploadReceipt,
            uploaderUserId: String,
            nowIso: () -> String = { java.time.Instant.now().toString() },
        ): EvidenceRegisterPayload? {
            val kind = evidenceKindFor(upload.contextType) ?: return null
            if (upload.contextId.isBlank()) return null
            return EvidenceRegisterPayload(
                evidenceKind = kind,
                sourceKind = SOURCE_REPAIR_JOB,
                sourceId = upload.contextId,
                contentSha256 = receipt.sha256Hex,
                contentSizeBytes = receipt.sizeBytes,
                storageUrl = "${receipt.bucket}/${receipt.objectPath}",
                producerKind = PRODUCER_ENGINEER,
                producerUserId = uploaderUserId,
                capturedAt = nowIso(),
                mimeType = upload.mimeType,
            )
        }
    }
}
