package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Test

class ConversationRowHelpersTest {

    // ---- conversationRowTitle ----------------------------------------

    @Test fun `non-null counterpart name passes through`() {
        assertEquals("Asha Rao", conversationRowTitle("Asha Rao"))
    }

    @Test fun `null counterpart name falls back to Conversation`() {
        // Critical pin — Title-cased singular "Conversation" not
        // "Unknown" / "?". Preserves the row's tap affordance.
        assertEquals("Conversation", conversationRowTitle(null))
    }

    @Test fun `empty counterpart name passes through verbatim (not folded)`() {
        // Pin exact null gate. Empty string stays empty — the wire
        // shouldn't allow this, but pin the total shape.
        assertEquals("", conversationRowTitle(""))
    }

    // ---- conversationRowPreview --------------------------------------

    @Test fun `non-blank last message passes through`() {
        assertEquals(
            "Hello, I'm on my way",
            conversationRowPreview("Hello, I'm on my way"),
        )
    }

    @Test fun `null last message falls back to No messages yet`() {
        // Critical pin — "No messages yet" reads as deliberately
        // fresh row. A refactor to "No content" / empty would read
        // as broken.
        assertEquals(
            "No messages yet",
            conversationRowPreview(null),
        )
    }

    @Test fun `blank last message falls back to No messages yet`() {
        // takeIf isNotBlank gates this — whitespace-only message
        // (defensive) falls through to fresh-row copy.
        assertEquals(
            "No messages yet",
            conversationRowPreview(""),
        )
        assertEquals(
            "No messages yet",
            conversationRowPreview("   "),
        )
    }

    @Test fun `No messages yet literal is preserved verbatim`() {
        // Pin "No messages yet" — distinct from "No messages" (which
        // would imply finality / archive) or "Tap to start a chat"
        // (which would be a CTA, not a preview).
        val out = conversationRowPreview(null)
        assertEquals("No messages yet", out)
    }
}
