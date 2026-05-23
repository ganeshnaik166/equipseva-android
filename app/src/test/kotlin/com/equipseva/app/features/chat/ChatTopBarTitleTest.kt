package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ChatTopBarTitleTest {

    @Test fun `non-null counterpart name passes through`() {
        assertEquals("Asha Rao", chatTopBarTitle("Asha Rao"))
    }

    @Test fun `null counterpart name falls back to Chat`() {
        // Critical pin — "Chat" not "Conversation".
        assertEquals("Chat", chatTopBarTitle(null))
    }

    @Test fun `cross-helper distinction — chat top bar vs conversation row`() {
        // Critical pin — the asymmetric fallbacks reflect surface
        // semantics:
        //   - Single-thread top bar: "Chat" (activity)
        //   - List row: "Conversation" (inbox item noun)
        // A unifying refactor would surface the wrong term on one
        // side.
        assertNotEquals(
            chatTopBarTitle(null),
            conversationRowTitle(null),
        )
        assertEquals("Chat", chatTopBarTitle(null))
        assertEquals("Conversation", conversationRowTitle(null))
    }

    @Test fun `empty counterpart name passes through (not folded)`() {
        // Pin exact null gate.
        assertEquals("", chatTopBarTitle(""))
    }
}
