package com.equipseva.app.core.sync

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the outbox kind ID constants. These string literals are stored
 * verbatim in the `outbox_entries.kind` column on every queued row,
 * including rows queued before an app upgrade. A rename here would
 * orphan every persisted row of the renamed kind (no handler matches
 * → either silently leaks queue entries or burns the MAX_ATTEMPTS
 * budget on every flush).
 *
 * Add a new kind here is a one-way migration; pin so the existing
 * values stay frozen.
 */
class OutboxKindsTest {

    @Test fun `kind ids are the pinned wire strings`() {
        assertEquals("chat_message", OutboxKinds.CHAT_MESSAGE)
        assertEquals("repair_bid", OutboxKinds.REPAIR_BID)
        assertEquals("job_status", OutboxKinds.JOB_STATUS)
        assertEquals("photo_upload", OutboxKinds.PHOTO_UPLOAD)
        assertEquals("notification_read", OutboxKinds.NOTIFICATION_READ)
    }

    @Test fun `kind ids are all distinct`() {
        val ids = listOf(
            OutboxKinds.CHAT_MESSAGE,
            OutboxKinds.REPAIR_BID,
            OutboxKinds.JOB_STATUS,
            OutboxKinds.PHOTO_UPLOAD,
            OutboxKinds.NOTIFICATION_READ,
        )
        assertEquals(ids.size, ids.toSet().size)
    }
}
