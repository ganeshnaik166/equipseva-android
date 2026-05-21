package com.equipseva.app.core.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-kind poison-drop notification copy. The user sees this
 * text after MAX_ATTEMPTS retries of an offline write — the body
 * must point them at the surface where they can recover (conversation
 * / job detail / etc.). A generic fallback covers any future kind so
 * an unknown kind doesn't crash the worker.
 */
class PoisonDropCopyTest {

    @Test fun `chat message kind references conversation retype`() {
        val (title, body) = poisonDropCopy(OutboxKinds.CHAT_MESSAGE)
        assertEquals("Couldn't send a chat message", title)
        assertTrue(
            "body should point at conversation: $body",
            body.contains("conversation", ignoreCase = true),
        )
    }

    @Test fun `photo upload kind references re-attaching the photo`() {
        val (title, body) = poisonDropCopy(OutboxKinds.PHOTO_UPLOAD)
        assertEquals("Couldn't upload a photo", title)
        assertTrue(
            "body should mention re-attach: $body",
            body.contains("re-attach", ignoreCase = true),
        )
    }

    @Test fun `repair bid kind tells user the previous attempt was discarded`() {
        val (title, body) = poisonDropCopy(OutboxKinds.REPAIR_BID)
        assertEquals("Couldn't place your bid", title)
        assertTrue(
            "body should mention retry: $body",
            body.contains("retry", ignoreCase = true),
        )
    }

    @Test fun `job status kind points at re-tap status button`() {
        val (title, body) = poisonDropCopy(OutboxKinds.JOB_STATUS)
        assertEquals("Couldn't sync a job status update", title)
        assertTrue(
            "body should mention status button: $body",
            body.contains("status button", ignoreCase = true),
        )
    }

    @Test fun `unknown kind falls back to generic queued-action copy`() {
        // Forward-compat: a new kind shipped without a per-kind
        // copy entry surfaces with a generic title/body rather than
        // crashing the worker on a non-exhaustive when.
        val (title, body) = poisonDropCopy("future_kind")
        assertEquals("Couldn't sync a queued action", title)
        assertTrue(
            "body should mention discarded: $body",
            body.contains("discarded", ignoreCase = true),
        )
    }

    @Test fun `every known OutboxKinds value has dedicated copy (not generic fallback)`() {
        // Defense — if a new entry is added to OutboxKinds it must
        // have a dedicated entry here too. Pin so the generic
        // fallback is reserved for forward-compat only.
        val genericTitle = "Couldn't sync a queued action"
        listOf(
            OutboxKinds.CHAT_MESSAGE,
            OutboxKinds.REPAIR_BID,
            OutboxKinds.JOB_STATUS,
            OutboxKinds.PHOTO_UPLOAD,
            // NOTIFICATION_READ deliberately uses generic copy — a
            // failed read-state sync is not user-actionable.
        ).forEach { kind ->
            val (title, _) = poisonDropCopy(kind)
            assertTrue(
                "kind $kind should have dedicated title, got generic",
                title != genericTitle,
            )
        }
    }

    @Test fun `notification read kind uses generic fallback (not user-actionable)`() {
        // Failed read-state sync isn't worth a user-actionable hint;
        // it falls through to the generic copy by design.
        val (title, _) = poisonDropCopy(OutboxKinds.NOTIFICATION_READ)
        assertEquals("Couldn't sync a queued action", title)
    }
}
