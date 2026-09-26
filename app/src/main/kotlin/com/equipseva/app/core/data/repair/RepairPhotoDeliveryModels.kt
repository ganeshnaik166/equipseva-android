package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.RepairPhotoDeliveryEntity
import com.equipseva.app.core.data.entities.RepairPhotoDeliveryFenceEntity
import java.io.File
import java.time.Instant
import java.util.UUID

data class PhotoDeliveryScope(val ownerId: String, val sessionId: String, val generation: Long)

data class PreparedRepairPhoto(
    val operationId: String,
    val jobId: String,
    val evidenceKind: String,
    val objectPath: String,
    val preparedFilePath: String,
    val contentSha256: String,
    val contentSizeBytes: Long,
    val mimeType: String,
    val capturedAt: String,
    val captureProvenance: String,
    val createdAt: Long,
    val formatVersion: Int = 1,
)

data class UploadedRepairPhotoReceipt(val storageUrl: String, val sha256: String, val sizeBytes: Long, val mimeType: String)

/** Opaque compare-and-swap coordinates. The DAO always reloads mutable row state. */
class PhotoDeliveryClaim internal constructor(
    val operationId: String,
    val scope: PhotoDeliveryScope,
    val revision: Long,
    val token: String,
    val startedAt: Long,
    val expiresAt: Long,
)

enum class PhotoDeliveryError {
    NETWORK, AUTH_REQUIRED, OBJECT_CONFLICT, RECEIPT_INVALID, LOCAL_FILE_MISSING, CLEANUP_FAILED,
}

object PhotoDeliveryPhase {
    const val PREPARED = "Prepared"
    const val UPLOADED = "Uploaded"
    const val REGISTERED = "Registered"
    const val NEEDS_ATTENTION = "NeedsAttention"
}

object PhotoCleanupState {
    const val RETAINED = "Retained"
    const val PENDING = "Pending"
    const val NEEDS_ATTENTION = "NeedsAttention"
}

/**
 * Lease timestamps use one caller-supplied epoch-millisecond clock. Clock
 * jumps do not prove elapsed time; turnover still fences the former token
 * and revision. A time before claim acquisition cannot authorize a mutation.
 */
object PhotoDeliveryPolicy {
    const val MAX_FILE_BYTES = 10L * 1024 * 1024
    const val MAX_CLAIM_MILLIS = 15L * 60 * 1000
    const val MAX_RETRY_DELAY_MILLIS = 24L * 60 * 60 * 1000
    const val MAX_ATTEMPTS = 5

    fun isUuid(value: String): Boolean = runCatching { UUID.fromString(value).toString() == value }.getOrDefault(false)
    fun validScope(scope: PhotoDeliveryScope): Boolean =
        isUuid(scope.ownerId) && isUuid(scope.sessionId) && scope.generation > 0

    fun deadline(now: Long, duration: Long, maximum: Long): Long? =
        if (now < 0 || duration <= 0 || duration > maximum || now > Long.MAX_VALUE - duration) null else now + duration

    fun nextVersion(version: Long): Long? = if (version < 0 || version == Long.MAX_VALUE) null else version + 1

    fun validPrepared(scope: PhotoDeliveryScope, photo: PreparedRepairPhoto): Boolean {
        val segments = photo.objectPath.split('/')
        val extension = when (photo.mimeType) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            else -> return false
        }
        val operationFileName = "${photo.operationId}.$extension"
        val preparedFile = File(photo.preparedFilePath)
        return photo.formatVersion == 1 && validScope(scope) && isUuid(photo.operationId) && isUuid(photo.jobId) &&
            photo.evidenceKind in setOf("photo_before", "photo_after") &&
            segments.size == 3 && segments[0] == scope.ownerId && segments[1] == photo.jobId &&
            segments[2] == operationFileName &&
            photo.preparedFilePath.isNotBlank() && preparedFile.isAbsolute &&
            photo.preparedFilePath.none { it.isISOControl() } &&
            preparedFile.normalize().path == preparedFile.path && preparedFile.name == operationFileName &&
            photo.contentSha256.matches(Regex("[0-9a-f]{64}")) && photo.contentSizeBytes in 1..MAX_FILE_BYTES &&
            photo.captureProvenance in setOf("client_save_time", "client_asserted") &&
            runCatching { Instant.parse(photo.capturedAt) }.isSuccess && photo.createdAt >= 0
    }

    fun activeClaim(row: RepairPhotoDeliveryEntity, claim: PhotoDeliveryClaim, now: Long): Boolean =
        now >= 0 && row.operationId == claim.operationId && row.scope() == claim.scope &&
            row.revision == claim.revision && row.claimToken == claim.token &&
            row.claimStartedAt == claim.startedAt && row.claimExpiresAt == claim.expiresAt &&
            now >= claim.startedAt && now < claim.expiresAt
}

fun RepairPhotoDeliveryEntity.scope(): PhotoDeliveryScope = PhotoDeliveryScope(ownerId, sessionId, generation)
fun RepairPhotoDeliveryFenceEntity.scope(): PhotoDeliveryScope = PhotoDeliveryScope(ownerId, sessionId, generation)

internal fun PreparedRepairPhoto.toEntity(scope: PhotoDeliveryScope) = RepairPhotoDeliveryEntity(
    operationId, formatVersion, scope.ownerId, scope.sessionId, scope.generation, jobId, evidenceKind, objectPath,
    preparedFilePath, contentSha256, contentSizeBytes, mimeType, capturedAt, captureProvenance,
    PhotoDeliveryPhase.PREPARED, null, null, null, PhotoCleanupState.RETAINED, false,
    0, null, null, null, 0, 0, null, createdAt,
)

internal fun RepairPhotoDeliveryEntity.sameIntent(other: RepairPhotoDeliveryEntity): Boolean =
    operationId == other.operationId && formatVersion == other.formatVersion && scope() == other.scope() && jobId == other.jobId &&
        evidenceKind == other.evidenceKind && objectPath == other.objectPath && preparedFilePath == other.preparedFilePath &&
        contentSha256 == other.contentSha256 && contentSizeBytes == other.contentSizeBytes &&
        mimeType == other.mimeType && capturedAt == other.capturedAt && captureProvenance == other.captureProvenance && createdAt == other.createdAt

internal fun RepairPhotoDeliveryEntity.toClaim(): PhotoDeliveryClaim? {
    val token = claimToken ?: return null
    val startedAt = claimStartedAt ?: return null
    val expiresAt = claimExpiresAt ?: return null
    return PhotoDeliveryClaim(operationId, scope(), revision, token, startedAt, expiresAt)
}
