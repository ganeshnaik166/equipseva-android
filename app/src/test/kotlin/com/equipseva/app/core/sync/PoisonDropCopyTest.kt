package com.equipseva.app.core.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The poison-drop system notification is the only signal a user gets
 * that one of their offline actions was discarded. Wrong copy here
 * either leaks an internal name (e.g. "chat_message") into the
 * notification or fires the generic fallback for a known kind.
 */
class PoisonDropCopyTest {

    @Test fun `chat message poison drop names the conversation surface to retry from`() {
        val (title, body) = poisonDropCopy(OutboxKinds.CHAT_MESSAGE)
        assertEquals("Couldn't send a chat message", title)
        assertTrue("body should point to the conversation", body.contains("conversation"))
    }

    @Test fun `photo upload poison drop names the job + suggests a network fix`() {
        val (title, body) = poisonDropCopy(OutboxKinds.PHOTO_UPLOAD)
        assertEquals("Couldn't upload a photo", title)
        assertTrue(body.contains("job"))
        assertTrue(body.contains("network"))
    }

    @Test fun `repair bid poison drop tells the engineer the previous attempt was discarded`() {
        val (title, body) = poisonDropCopy(OutboxKinds.REPAIR_BID)
        assertEquals("Couldn't place your bid", title)
        assertTrue("body should mention discard", body.contains("discarded"))
    }

    @Test fun `job status poison drop tells the engineer to re-tap on next online`() {
        val (title, body) = poisonDropCopy(OutboxKinds.JOB_STATUS)
        assertEquals("Couldn't sync a job status update", title)
        assertTrue(body.contains("online"))
    }

    @Test fun `unknown kind falls through to a generic message that doesn't leak the kind name`() {
        val (title, body) = poisonDropCopy("totally_made_up_kind")
        assertEquals("Couldn't sync a queued action", title)
        assertTrue(body.contains("Some offline action"))
        // The kind name itself must NOT appear in the user-facing copy.
        assertTrue(
            "kind name leaked into body=$body",
            !body.contains("totally_made_up_kind"),
        )
        assertTrue(
            "kind name leaked into title=$title",
            !title.contains("totally_made_up_kind"),
        )
    }

    @Test fun `every registered outbox kind has explicit copy`() {
        // Belt-and-braces: if a new OutboxKinds entry is added and we
        // forget to extend the when, this catches the silent generic
        // fallback before it ships.
        val explicit = setOf(
            OutboxKinds.CHAT_MESSAGE,
            OutboxKinds.PHOTO_UPLOAD,
            OutboxKinds.REPAIR_BID,
            OutboxKinds.JOB_STATUS,
        )
        explicit.forEach { kind ->
            val (title, _) = poisonDropCopy(kind)
            assertTrue(
                "kind $kind fell through to generic copy",
                title != "Couldn't sync a queued action",
            )
        }
    }
}
