package com.equipseva.app.core.sync.handlers

import com.equipseva.app.core.storage.StorageRepository
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * round3820 — pins which uploads become §65B evidence and what the ledger
 * registration carries. A wrong mapping here either leaks non-evidence
 * (KYC documents!) into the repair-job chain or silently drops the photos
 * the chain exists for.
 */
class EvidenceRegisterPayloadTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun upload(contextType: String, contextId: String = "job-1") = PhotoUploadPayload(
        bucket = "repair-photos",
        objectPath = "u1/before-1.jpg",
        localFilePath = "/tmp/x.jpg",
        mimeType = "image/jpeg",
        contextType = contextType,
        contextId = contextId,
        uploaderUserId = "u1",
    )

    private val receipt = StorageRepository.UploadReceipt(
        bucket = "repair-photos",
        objectPath = "u1/before-1.jpg",
        sha256Hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        sizeBytes = 3,
    )

    @Test fun `before photos register as photo_before`() {
        assertEquals("photo_before", EvidenceRegisterPayload.evidenceKindFor(PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE))
    }

    @Test fun `after photos register as photo_after`() {
        assertEquals("photo_after", EvidenceRegisterPayload.evidenceKindFor(PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER))
    }

    @Test fun `issue photos and KYC docs are NOT repair-job evidence`() {
        assertNull(EvidenceRegisterPayload.evidenceKindFor(PhotoUploadPayload.CONTEXT_REPAIR_JOB_ISSUE))
        assertNull(EvidenceRegisterPayload.evidenceKindFor(PhotoUploadPayload.CONTEXT_KYC_DOC))
        assertNull(EvidenceRegisterPayload.evidenceKindFor("something_new"))
        assertNull(EvidenceRegisterPayload.forUploadedPhoto(upload(PhotoUploadPayload.CONTEXT_KYC_DOC), receipt, "u1"))
    }

    @Test fun `blank contextId yields no registration`() {
        assertNull(EvidenceRegisterPayload.forUploadedPhoto(upload(PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE, contextId = ""), receipt, "u1"))
    }

    @Test fun `payload carries the receipt hash, size, storage path and producer`() {
        val p = EvidenceRegisterPayload.forUploadedPhoto(
            upload(PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER),
            receipt,
            uploaderUserId = "u1",
            nowIso = { "2026-09-07T05:00:00Z" },
        )!!
        assertEquals("photo_after", p.evidenceKind)
        assertEquals("repair_job", p.sourceKind)
        assertEquals("job-1", p.sourceId)
        assertEquals(receipt.sha256Hex, p.contentSha256)
        assertEquals(3L, p.contentSizeBytes)
        assertEquals("repair-photos/u1/before-1.jpg", p.storageUrl)
        assertEquals("engineer", p.producerKind)
        assertEquals("u1", p.producerUserId)
        assertEquals("2026-09-07T05:00:00Z", p.capturedAt)
        assertEquals("image/jpeg", p.mimeType)
    }

    @Test fun `payload round-trips through the outbox JSON`() {
        val original = EvidenceRegisterPayload.forUploadedPhoto(
            upload(PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE), receipt, "u1", nowIso = { "2026-09-07T05:00:00Z" },
        )!!
        val encoded = json.encodeToString(EvidenceRegisterPayload.serializer(), original)
        assertEquals(original, json.decodeFromString(EvidenceRegisterPayload.serializer(), encoded))
    }
}
