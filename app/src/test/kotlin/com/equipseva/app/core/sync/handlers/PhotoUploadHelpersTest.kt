package com.equipseva.app.core.sync.handlers

import com.equipseva.app.core.storage.UploadError
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * The photo-upload outbox handler's poison-vs-retry decision and
 * context-type → column mapping are pure — pulled out so the retry
 * vs give-up branches are testable without standing up a Worker.
 */
class PhotoUploadHelpersTest {

    @Test fun `UploadError variants are permanent — not transient`() {
        // Anything the client-side UploadValidator throws won't fix itself
        // on a retry — bad mime / size / path / bucket are deterministic.
        assertFalse(isTransientUploadError(UploadError.UnknownBucket("repair-photos-typo")))
        assertFalse(isTransientUploadError(UploadError.MimeNotAllowed("repair-photos", "image/heic", setOf("image/jpeg"))))
        assertFalse(isTransientUploadError(UploadError.TooLarge("repair-photos", 100L, 10L)))
        assertFalse(isTransientUploadError(UploadError.InvalidPath("../a.jpg", "traversal segment")))
    }

    @Test fun `IOException + generic errors are transient`() {
        // IO / network / RLS-5xx kinds all retry. The outbox worker has its
        // own MAX_ATTEMPTS cap on top of this signal.
        assertTrue(isTransientUploadError(IOException("offline")))
        assertTrue(isTransientUploadError(RuntimeException("supabase 503")))
        assertTrue(isTransientUploadError(IllegalStateException("no session")))
    }

    @Test fun `repair-job context types map to the expected column`() {
        assertEquals(
            "before_photos",
            photoContextColumn(PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE),
        )
        assertEquals(
            "after_photos",
            photoContextColumn(PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER),
        )
        assertEquals(
            "issue_photos",
            photoContextColumn(PhotoUploadPayload.CONTEXT_REPAIR_JOB_ISSUE),
        )
    }

    @Test fun `KYC doc context is upload-only — no column patch`() {
        // KYC docs are inserted by KycViewModel itself; the photo outbox
        // shouldn't try to patch a repair_jobs column for them.
        assertNull(photoContextColumn(PhotoUploadPayload.CONTEXT_KYC_DOC))
    }

    @Test fun `unknown context falls through to null`() {
        // Forward-compat: a new context type can land in the payload from
        // an updated server without the client crashing — it just won't
        // get the URL-append affordance until the client catches up.
        assertNull(photoContextColumn("rfq_photo"))
        assertNull(photoContextColumn(""))
    }
}
