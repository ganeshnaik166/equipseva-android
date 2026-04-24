package com.equipseva.app.core.sync.handlers

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Contract tests for [PhotoUploadPayload]'s serialized shape. The outbox
 * worker reads rows back as JSON after an app restart; breaking the wire
 * format silently is an invisible regression (old queued rows fail to
 * deserialize and get [OutboxKindHandler.Outcome.GiveUp]'d on drain,
 * losing user work).
 *
 * We pin:
 *  - Field names are the ones the handler expects.
 *  - The handler's context-type constants are the literal strings a future
 *    row-producer would hand us — no typo drift between sides.
 */
class PhotoUploadPayloadTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `round-trips through JSON preserving all fields`() {
        val original = PhotoUploadPayload(
            bucket = "repair-photos",
            objectPath = "uid-1/before/pic.jpg",
            localFilePath = "/data/data/app/files/photo-outbox/123-pic.jpg",
            mimeType = "image/jpeg",
            contextType = PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE,
            contextId = "job-42",
            uploaderUserId = "uid-1",
        )

        val encoded = json.encodeToString(PhotoUploadPayload.serializer(), original)
        val decoded = json.decodeFromString(PhotoUploadPayload.serializer(), encoded)

        assertEquals(original, decoded)
    }

    @Test fun `context constants are stable string keys`() {
        // These literal values end up persisted in the outbox table; renaming
        // the constants without a migration would orphan pending rows from the
        // previous build.
        assertEquals("repair_job_before", PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE)
        assertEquals("repair_job_after", PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER)
        assertEquals("repair_job_issue", PhotoUploadPayload.CONTEXT_REPAIR_JOB_ISSUE)
        assertEquals("kyc_doc", PhotoUploadPayload.CONTEXT_KYC_DOC)
    }

    @Test fun `max file size cap matches KYC bucket policy`() {
        // KYC allows 15 MB; the outbox cap should track the highest bucket
        // ceiling so a KYC doc isn't pre-emptively rejected by the payload
        // when the bucket itself would accept it.
        assertEquals(15L * 1024 * 1024, PhotoUploadPayload.MAX_FILE_SIZE_BYTES)
    }

    @Test fun `malformed JSON fails to decode`() {
        val result = runCatching {
            json.decodeFromString(PhotoUploadPayload.serializer(), "not-valid-json")
        }
        assertTrue(result.isFailure)
    }

    @Test fun `missing uploaderUserId fails to decode`() {
        // uploaderUserId is load-bearing for the owner gate — absence should
        // surface as a decode failure, not silently default to empty.
        val partial = """{
            "bucket":"repair-photos",
            "objectPath":"a/b.jpg",
            "localFilePath":"/tmp/x",
            "mimeType":"image/jpeg",
            "contextType":"repair_job_before",
            "contextId":"job-1"
        }""".trimIndent()

        val result = runCatching {
            json.decodeFromString(PhotoUploadPayload.serializer(), partial)
        }
        assertTrue(result.isFailure)
    }
}
