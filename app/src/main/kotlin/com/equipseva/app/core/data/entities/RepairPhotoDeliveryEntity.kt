package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/** Receipt fields describe prepared bytes; they are not a server-verified digest. */
@Entity(
    tableName = "repair_photo_deliveries",
    indices = [
        Index(value = ["ownerId", "sessionId", "generation", "createdAt"]),
        Index(value = ["objectPath"], unique = true),
        Index(value = ["preparedFilePath"], unique = true),
    ],
)
data class RepairPhotoDeliveryEntity(
    @PrimaryKey val operationId: String,
    val formatVersion: Int,
    val ownerId: String,
    val sessionId: String,
    val generation: Long,
    val jobId: String,
    val evidenceKind: String,
    val objectPath: String,
    val preparedFilePath: String?,
    val contentSha256: String,
    val contentSizeBytes: Long,
    val mimeType: String,
    val capturedAt: String,
    val captureProvenance: String,
    val phase: String,
    val resumePhase: String?,
    val ledgerId: String?,
    val registeredAttachmentPath: String?,
    val cleanupState: String,
    val removalRequested: Boolean,
    val revision: Long,
    val claimToken: String?,
    val claimStartedAt: Long?,
    val claimExpiresAt: Long?,
    val attempts: Int,
    val nextAttemptAt: Long,
    val lastErrorCode: String?,
    val createdAt: Long,
)

/** Only the auth coordinator activates or invalidates this singleton fence. */
@Entity(tableName = "repair_photo_delivery_fence")
data class RepairPhotoDeliveryFenceEntity(
    @PrimaryKey val id: Int = 1,
    val ownerId: String,
    val sessionId: String,
    val generation: Long,
    val revision: Long,
    val active: Boolean,
)

/** Retains no photo, job or account data, but prevents operation-ID reuse. */
@Entity(tableName = "repair_photo_delivery_retired")
data class RetiredRepairPhotoDeliveryEntity(@PrimaryKey val operationId: String)
