package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.equipseva.app.core.data.entities.RepairPhotoDeliveryEntity
import com.equipseva.app.core.data.entities.RepairPhotoDeliveryFenceEntity
import com.equipseva.app.core.data.entities.RetiredRepairPhotoDeliveryEntity
import com.equipseva.app.core.data.repair.PhotoCleanupState
import com.equipseva.app.core.data.repair.PhotoDeliveryClaim
import com.equipseva.app.core.data.repair.PhotoDeliveryError
import com.equipseva.app.core.data.repair.PhotoDeliveryPhase
import com.equipseva.app.core.data.repair.PhotoDeliveryPolicy
import com.equipseva.app.core.data.repair.PhotoDeliveryScope
import com.equipseva.app.core.data.repair.PreparedRepairPhoto
import com.equipseva.app.core.data.repair.UploadedRepairPhotoReceipt
import com.equipseva.app.core.data.repair.sameIntent
import com.equipseva.app.core.data.repair.scope
import com.equipseva.app.core.data.repair.toClaim
import com.equipseva.app.core.data.repair.toEntity

/**
 * Durable local repair-photo state machine.
 *
 * Every public read and write is fenced inside the Room transaction. Claim
 * coordinates are compare-and-swap inputs only: mutable values are always
 * reloaded from SQLite. The trusted auth coordinator is the only caller that
 * may activate or deactivate the singleton fence.
 */
@Dao
abstract class RepairPhotoDeliveryDao {
    @Query("SELECT * FROM repair_photo_delivery_fence WHERE id = 1")
    protected abstract suspend fun rawFence(): RepairPhotoDeliveryFenceEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    protected abstract suspend fun insertFence(row: RepairPhotoDeliveryFenceEntity): Long

    @Query(
        """
        UPDATE repair_photo_delivery_fence
        SET ownerId = :ownerId, sessionId = :sessionId, generation = :generation,
            revision = :revision, active = :active
        WHERE id = 1 AND revision = :expectedRevision
        """,
    )
    protected abstract suspend fun replaceFence(
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        active: Boolean,
        expectedRevision: Long,
    ): Int

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    protected abstract suspend fun insertDelivery(row: RepairPhotoDeliveryEntity): Long

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    protected abstract suspend fun insertRetired(row: RetiredRepairPhotoDeliveryEntity): Long

    @Query("SELECT COUNT(*) FROM repair_photo_delivery_retired WHERE operationId = :operationId")
    protected abstract suspend fun retiredCount(operationId: String): Int

    @Query(
        """
        SELECT d.* FROM repair_photo_deliveries d
        WHERE d.operationId = :operationId
          AND d.ownerId = :ownerId AND d.sessionId = :sessionId AND d.generation = :generation
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun scopedDelivery(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
    ): RepairPhotoDeliveryEntity?

    @Query(
        """
        SELECT d.* FROM repair_photo_deliveries d
        WHERE d.ownerId = :ownerId AND d.sessionId = :sessionId AND d.generation = :generation
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        ORDER BY d.createdAt, d.operationId
        """,
    )
    protected abstract suspend fun scopedDeliveries(
        ownerId: String,
        sessionId: String,
        generation: Long,
    ): List<RepairPhotoDeliveryEntity>

    @Query(
        """
        SELECT d.* FROM repair_photo_deliveries d
        WHERE d.ownerId = :ownerId AND d.sessionId = :sessionId AND d.generation = :generation
          AND d.nextAttemptAt <= :now AND d.revision < :maxRevision
          AND (
            ((d.removalRequested = 1 OR d.phase = 'Registered') AND d.cleanupState = 'Pending')
            OR
            (d.removalRequested = 0 AND d.phase IN ('Prepared', 'Uploaded') AND d.cleanupState = 'Retained')
          )
          AND (
            d.claimToken IS NULL
            OR (d.claimStartedAt IS NOT NULL AND d.claimExpiresAt IS NOT NULL
                AND :now >= d.claimStartedAt AND :now >= d.claimExpiresAt)
          )
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        ORDER BY d.nextAttemptAt, d.createdAt, d.operationId
        LIMIT 1
        """,
    )
    protected abstract suspend fun nextEligible(
        ownerId: String,
        sessionId: String,
        generation: Long,
        now: Long,
        maxRevision: Long = Long.MAX_VALUE,
    ): RepairPhotoDeliveryEntity?

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET claimToken = :token, claimStartedAt = :now, claimExpiresAt = :expiresAt,
            revision = revision + 1
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :expectedRevision AND revision < :maxRevision
          AND nextAttemptAt <= :now
          AND (
            ((removalRequested = 1 OR phase = 'Registered') AND cleanupState = 'Pending')
            OR
            (removalRequested = 0 AND phase IN ('Prepared', 'Uploaded') AND cleanupState = 'Retained')
          )
          AND (
            claimToken IS NULL
            OR (claimStartedAt IS NOT NULL AND claimExpiresAt IS NOT NULL
                AND :now >= claimStartedAt AND :now >= claimExpiresAt)
          )
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun claimEligible(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        expectedRevision: Long,
        token: String,
        now: Long,
        expiresAt: Long,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET phase = 'Uploaded', resumePhase = NULL, revision = revision + 1,
            claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL,
            attempts = 0, nextAttemptAt = 0, lastErrorCode = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND phase = 'Prepared' AND removalRequested = 0 AND cleanupState = 'Retained'
          AND objectPath = :objectPath AND contentSha256 = :sha256
          AND contentSizeBytes = :sizeBytes AND mimeType = :mimeType
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun advanceUploaded(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
        objectPath: String,
        sha256: String,
        sizeBytes: Long,
        mimeType: String,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET phase = 'Registered', resumePhase = NULL, ledgerId = :ledgerId,
            registeredAttachmentPath = :attachmentPath, cleanupState = 'Pending',
            revision = revision + 1, claimToken = NULL, claimStartedAt = NULL,
            claimExpiresAt = NULL, attempts = 0, nextAttemptAt = 0, lastErrorCode = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND phase = 'Uploaded' AND removalRequested = 0 AND cleanupState = 'Retained'
          AND objectPath = :attachmentPath
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun advanceRegistered(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
        ledgerId: String,
        attachmentPath: String,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET phase = :phase, resumePhase = :resumePhase, attempts = :attempts,
            nextAttemptAt = :nextAttemptAt, lastErrorCode = :errorCode,
            revision = revision + 1, claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND phase IN ('Prepared', 'Uploaded') AND removalRequested = 0 AND cleanupState = 'Retained'
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun updateRetry(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
        phase: String,
        resumePhase: String?,
        attempts: Int,
        nextAttemptAt: Long,
        errorCode: String,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET cleanupState = :cleanupState, attempts = :attempts,
            nextAttemptAt = :nextAttemptAt, lastErrorCode = 'CLEANUP_FAILED',
            revision = revision + 1, claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND (removalRequested = 1 OR phase = 'Registered') AND cleanupState = 'Pending'
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun updateCleanupFailure(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
        cleanupState: String,
        attempts: Int,
        nextAttemptAt: Long,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET revision = revision + 1, claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun clearClaim(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET removalRequested = 1, cleanupState = 'Pending', attempts = 0,
            nextAttemptAt = 0, lastErrorCode = NULL, revision = revision + 1,
            claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun markRemovalRequested(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        UPDATE repair_photo_deliveries
        SET phase = :phase, resumePhase = NULL, cleanupState = :cleanupState,
            attempts = 0, nextAttemptAt = 0, lastErrorCode = NULL,
            revision = revision + 1, claimToken = NULL, claimStartedAt = NULL, claimExpiresAt = NULL
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision AND revision < :maxRevision
          AND ((phase = 'NeedsAttention' AND resumePhase IN ('Prepared', 'Uploaded') AND cleanupState = 'Retained')
               OR cleanupState = 'NeedsAttention')
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun resetAttention(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        phase: String,
        cleanupState: String,
        maxRevision: Long = Long.MAX_VALUE,
    ): Int

    @Query(
        """
        DELETE FROM repair_photo_deliveries
        WHERE operationId = :operationId AND ownerId = :ownerId AND sessionId = :sessionId
          AND generation = :generation AND revision = :revision
          AND claimToken = :token AND claimStartedAt = :startedAt AND claimExpiresAt = :expiresAt
          AND :now >= claimStartedAt AND :now < claimExpiresAt
          AND (removalRequested = 1 OR phase = 'Registered') AND cleanupState = 'Pending'
          AND EXISTS (
            SELECT 1 FROM repair_photo_delivery_fence f
            WHERE f.id = 1 AND f.active = 1 AND f.ownerId = :ownerId
              AND f.sessionId = :sessionId AND f.generation = :generation
          )
        """,
    )
    protected abstract suspend fun deleteAfterCleanup(
        operationId: String,
        ownerId: String,
        sessionId: String,
        generation: Long,
        revision: Long,
        token: String,
        startedAt: Long,
        expiresAt: Long,
        now: Long,
    ): Int

    /** Trusted coordinator snapshot used to supply the next expected fence revision. */
    @Transaction
    open suspend fun fenceSnapshot(): RepairPhotoDeliveryFenceEntity? = rawFence()

    @Transaction
    open suspend fun activate(
        ownerId: String,
        sessionId: String,
        expectedFenceRevision: Long?,
    ): RepairPhotoDeliveryFenceEntity? {
        if (!PhotoDeliveryPolicy.isUuid(ownerId) || !PhotoDeliveryPolicy.isUuid(sessionId)) return null
        val current = rawFence()
        if (current == null) {
            if (expectedFenceRevision != null) return null
            val initial = RepairPhotoDeliveryFenceEntity(ownerId = ownerId, sessionId = sessionId, generation = 1, revision = 0, active = true)
            return initial.takeIf { insertFence(it) != -1L }
        }
        if (current.revision != expectedFenceRevision) return null
        if (current.active && current.ownerId == ownerId && current.sessionId == sessionId) return current
        val generation = PhotoDeliveryPolicy.nextVersion(current.generation) ?: return null
        val revision = PhotoDeliveryPolicy.nextVersion(current.revision) ?: return null
        return if (replaceFence(ownerId, sessionId, generation, revision, true, current.revision) == 1) {
            rawFence()
        } else null
    }

    @Transaction
    open suspend fun deactivate(scope: PhotoDeliveryScope, expectedFenceRevision: Long): RepairPhotoDeliveryFenceEntity? {
        if (!PhotoDeliveryPolicy.validScope(scope)) return null
        val current = rawFence() ?: return null
        if (!current.active || current.scope() != scope || current.revision != expectedFenceRevision) return null
        val generation = PhotoDeliveryPolicy.nextVersion(current.generation) ?: return null
        val revision = PhotoDeliveryPolicy.nextVersion(current.revision) ?: return null
        return if (replaceFence(current.ownerId, current.sessionId, generation, revision, false, current.revision) == 1) {
            rawFence()
        } else null
    }

    @Transaction
    open suspend fun create(scope: PhotoDeliveryScope, photo: PreparedRepairPhoto): RepairPhotoDeliveryEntity? {
        if (!PhotoDeliveryPolicy.validPrepared(scope, photo) || retiredCount(photo.operationId) != 0) return null
        val fence = rawFence()
        if (fence?.active != true || fence.scope() != scope) return null
        val candidate = photo.toEntity(scope)
        if (insertDelivery(candidate) != -1L) return candidate
        return scopedDelivery(photo.operationId, scope.ownerId, scope.sessionId, scope.generation)
            ?.takeIf { it.sameIntent(candidate) }
    }

    @Transaction
    open suspend fun get(scope: PhotoDeliveryScope, operationId: String): RepairPhotoDeliveryEntity? =
        if (PhotoDeliveryPolicy.validScope(scope) && PhotoDeliveryPolicy.isUuid(operationId)) {
            scopedDelivery(operationId, scope.ownerId, scope.sessionId, scope.generation)
        } else null

    @Transaction
    open suspend fun list(scope: PhotoDeliveryScope): List<RepairPhotoDeliveryEntity> =
        if (PhotoDeliveryPolicy.validScope(scope)) {
            scopedDeliveries(scope.ownerId, scope.sessionId, scope.generation)
        } else emptyList()

    @Transaction
    open suspend fun claimNext(scope: PhotoDeliveryScope, now: Long, durationMillis: Long, token: String): PhotoDeliveryClaim? {
        if (!PhotoDeliveryPolicy.validScope(scope) || !PhotoDeliveryPolicy.isUuid(token)) return null
        val expiresAt = PhotoDeliveryPolicy.deadline(now, durationMillis, PhotoDeliveryPolicy.MAX_CLAIM_MILLIS) ?: return null
        val candidate = nextEligible(scope.ownerId, scope.sessionId, scope.generation, now) ?: return null
        if (claimEligible(candidate.operationId, scope.ownerId, scope.sessionId, scope.generation, candidate.revision, token, now, expiresAt) != 1) return null
        return scopedDelivery(candidate.operationId, scope.ownerId, scope.sessionId, scope.generation)?.toClaim()
    }

    @Transaction
    open suspend fun markUploaded(claim: PhotoDeliveryClaim, receipt: UploadedRepairPhotoReceipt, now: Long): RepairPhotoDeliveryEntity? {
        val row = freshClaim(claim, now) ?: return null
        if (receipt.storageUrl != "repair-photos/${row.objectPath}" || receipt.sha256 != row.contentSha256 ||
            receipt.sizeBytes != row.contentSizeBytes || receipt.mimeType != row.mimeType
        ) return null
        if (advanceUploaded(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now,
                row.objectPath, receipt.sha256, receipt.sizeBytes, receipt.mimeType) != 1
        ) return null
        return scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
    }

    @Transaction
    open suspend fun markRegistered(
        claim: PhotoDeliveryClaim,
        ledgerId: String,
        attachmentPath: String,
        now: Long,
    ): RepairPhotoDeliveryEntity? {
        val row = freshClaim(claim, now) ?: return null
        if (!PhotoDeliveryPolicy.isUuid(ledgerId) || attachmentPath != row.objectPath) return null
        if (advanceRegistered(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now, ledgerId, attachmentPath) != 1
        ) return null
        return scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
    }

    @Transaction
    open suspend fun recordRetry(
        claim: PhotoDeliveryClaim,
        now: Long,
        delayMillis: Long,
        error: PhotoDeliveryError,
    ): RepairPhotoDeliveryEntity? {
        if (error == PhotoDeliveryError.CLEANUP_FAILED) return null
        val row = freshClaim(claim, now) ?: return null
        if (row.phase !in setOf(PhotoDeliveryPhase.PREPARED, PhotoDeliveryPhase.UPLOADED) || row.attempts == Int.MAX_VALUE) return null
        val authPause = error == PhotoDeliveryError.AUTH_REQUIRED
        val deadline = if (authPause) 0 else {
            PhotoDeliveryPolicy.deadline(now, delayMillis, PhotoDeliveryPolicy.MAX_RETRY_DELAY_MILLIS) ?: return null
        }
        val attempts = if (authPause) row.attempts else row.attempts + 1
        val permanent = error in setOf(
            PhotoDeliveryError.OBJECT_CONFLICT,
            PhotoDeliveryError.RECEIPT_INVALID,
            PhotoDeliveryError.LOCAL_FILE_MISSING,
        )
        val exhausted = authPause || permanent || attempts >= PhotoDeliveryPolicy.MAX_ATTEMPTS
        val phase = if (exhausted) PhotoDeliveryPhase.NEEDS_ATTENTION else row.phase
        val resume = if (exhausted) row.phase else null
        val next = if (exhausted) 0 else deadline
        if (updateRetry(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now,
                phase, resume, attempts, next, error.name) != 1
        ) return null
        return scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
    }

    @Transaction
    open suspend fun recordCleanupFailure(
        claim: PhotoDeliveryClaim,
        now: Long,
        delayMillis: Long,
    ): RepairPhotoDeliveryEntity? {
        val deadline = PhotoDeliveryPolicy.deadline(now, delayMillis, PhotoDeliveryPolicy.MAX_RETRY_DELAY_MILLIS) ?: return null
        val row = freshClaim(claim, now) ?: return null
        if ((!row.removalRequested && row.phase != PhotoDeliveryPhase.REGISTERED) ||
            row.cleanupState != PhotoCleanupState.PENDING || row.attempts == Int.MAX_VALUE
        ) return null
        val attempts = row.attempts + 1
        val state = if (attempts >= PhotoDeliveryPolicy.MAX_ATTEMPTS) PhotoCleanupState.NEEDS_ATTENTION else PhotoCleanupState.PENDING
        val next = if (state == PhotoCleanupState.NEEDS_ATTENTION) 0 else deadline
        if (updateCleanupFailure(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now, state, attempts, next) != 1
        ) return null
        return scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
    }

    @Transaction
    open suspend fun release(claim: PhotoDeliveryClaim, now: Long): RepairPhotoDeliveryEntity? {
        if (freshClaim(claim, now) == null) return null
        if (clearClaim(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now) != 1
        ) return null
        return scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
    }

    @Transaction
    open suspend fun requestRemoval(scope: PhotoDeliveryScope, operationId: String, expectedRevision: Long): RepairPhotoDeliveryEntity? {
        if (!PhotoDeliveryPolicy.validScope(scope) || !PhotoDeliveryPolicy.isUuid(operationId) || expectedRevision < 0) return null
        if (markRemovalRequested(operationId, scope.ownerId, scope.sessionId, scope.generation, expectedRevision) != 1) return null
        return scopedDelivery(operationId, scope.ownerId, scope.sessionId, scope.generation)
    }

    @Transaction
    open suspend fun retryNeedsAttention(scope: PhotoDeliveryScope, operationId: String, expectedRevision: Long): RepairPhotoDeliveryEntity? {
        if (!PhotoDeliveryPolicy.validScope(scope) || !PhotoDeliveryPolicy.isUuid(operationId) || expectedRevision < 0) return null
        val row = scopedDelivery(operationId, scope.ownerId, scope.sessionId, scope.generation) ?: return null
        if (row.revision != expectedRevision) return null
        val resume = when {
            row.cleanupState == PhotoCleanupState.NEEDS_ATTENTION -> row.phase
            row.phase == PhotoDeliveryPhase.NEEDS_ATTENTION -> row.resumePhase ?: return null
            else -> return null
        }
        val cleanup = if (row.cleanupState == PhotoCleanupState.NEEDS_ATTENTION) PhotoCleanupState.PENDING else row.cleanupState
        if (resetAttention(operationId, scope.ownerId, scope.sessionId, scope.generation,
                expectedRevision, resume, cleanup) != 1
        ) return null
        return scopedDelivery(operationId, scope.ownerId, scope.sessionId, scope.generation)
    }

    /** Call only after the operation's prepared file is confirmed absent. */
    @Transaction
    open suspend fun acknowledgeCleanup(claim: PhotoDeliveryClaim, now: Long): Boolean {
        val row = freshClaim(claim, now) ?: return false
        if ((!row.removalRequested && row.phase != PhotoDeliveryPhase.REGISTERED) || row.cleanupState != PhotoCleanupState.PENDING) return false
        if (deleteAfterCleanup(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation,
                claim.revision, claim.token, claim.startedAt, claim.expiresAt, now) != 1
        ) return false
        check(insertRetired(RetiredRepairPhotoDeliveryEntity(claim.operationId)) != -1L) {
            "Retired repair-photo operation unexpectedly has a live delivery"
        }
        return true
    }

    @Transaction
    protected open suspend fun freshClaim(claim: PhotoDeliveryClaim, now: Long): RepairPhotoDeliveryEntity? {
        if (!PhotoDeliveryPolicy.validScope(claim.scope) || !PhotoDeliveryPolicy.isUuid(claim.operationId) ||
            !PhotoDeliveryPolicy.isUuid(claim.token)
        ) return null
        val row = scopedDelivery(claim.operationId, claim.scope.ownerId, claim.scope.sessionId, claim.scope.generation)
            ?: return null
        return row.takeIf { PhotoDeliveryPolicy.activeClaim(it, claim, now) }
    }
}
