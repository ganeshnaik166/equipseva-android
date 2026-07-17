package com.equipseva.app.features.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatCanSendAndEditTest {

    // ---- canSendChatMessage ------------------------------------------

    @Test fun `all conditions met returns true`() {
        assertTrue(
            canSendChatMessage(
                draft = "hello",
                sending = false,
                hasSelfUserId = true,
                counterpartBlocked = false,
            ),
        )
    }

    @Test fun `blank draft blocks send`() {
        assertFalse(
            canSendChatMessage("", false, true, false),
        )
        assertFalse(
            canSendChatMessage("   ", false, true, false),
        )
    }

    @Test fun `currently sending blocks send (prevents double-tap)`() {
        assertFalse(
            canSendChatMessage("hello", true, true, false),
        )
    }

    @Test fun `no self user id blocks send`() {
        // Pin — null subject would crash the insert.
        assertFalse(
            canSendChatMessage("hello", false, false, false),
        )
    }

    @Test fun `counterpart blocked blocks send (trust-and-safety)`() {
        // Critical pin — trust-and-safety regression target. A
        // refactor that dropped this gate would allow continued
        // harassment past the block.
        assertFalse(
            canSendChatMessage("hello", false, true, true),
        )
    }

    @Test fun `trimmed draft matters — trailing whitespace alone blocks`() {
        // Pin .trim() — a refactor to isNotBlank() on the raw string
        // would allow "   \n" through.
        assertFalse(
            canSendChatMessage("\n\t   ", false, true, false),
        )
    }

    @Test fun `closed conversation blocks send (r1495)`() {
        // The chat_messages_block_on_completed_job trigger rejects every
        // INSERT once the related job is completed/cancelled — the client
        // gate must mirror it so users can't compose a doomed message.
        assertFalse(
            canSendChatMessage("hello", false, true, false, conversationClosed = true),
        )
    }

    @Test fun `conversationClosed defaults to false (open chats unaffected)`() {
        // The default keeps every pre-r1495 call site (and a job whose
        // status hasn't loaded yet) sending normally.
        assertTrue(
            canSendChatMessage("hello", false, true, false),
        )
    }

    // ---- canSubmitChatEdit -------------------------------------------

    @Test fun `all edit conditions met returns true`() {
        assertTrue(
            canSubmitChatEdit(
                editingMessageId = "msg-123",
                editDraft = "edited content",
                editing = false,
            ),
        )
    }

    @Test fun `null editingMessageId blocks edit submit`() {
        // Not in edit mode.
        assertFalse(
            canSubmitChatEdit(null, "hello", false),
        )
    }

    @Test fun `blank editDraft blocks edit submit`() {
        // Pin — never send blank edits.
        assertFalse(
            canSubmitChatEdit("msg-1", "", false),
        )
        assertFalse(
            canSubmitChatEdit("msg-1", "   ", false),
        )
    }

    @Test fun `editDraft over 4000 chars blocks edit submit`() {
        // Critical pin — must match server-side messages.length CHECK.
        val long = "x".repeat(4001)
        assertFalse(
            canSubmitChatEdit("msg-1", long, false),
        )
    }

    @Test fun `editDraft at exactly 4000 chars is allowed`() {
        // Boundary — inclusive on the at-cap side.
        val exact = "x".repeat(4000)
        assertTrue(
            canSubmitChatEdit("msg-1", exact, false),
        )
    }

    @Test fun `currently editing blocks edit submit (prevents double-tap)`() {
        assertFalse(
            canSubmitChatEdit("msg-1", "edited", true),
        )
    }
}
