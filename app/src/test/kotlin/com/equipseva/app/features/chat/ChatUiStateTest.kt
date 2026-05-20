package com.equipseva.app.features.chat

import com.equipseva.app.core.data.chat.ChatMessage
import com.equipseva.app.core.data.profile.Profile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three derived properties on ChatViewModel.UiState — title,
 * canSend, canSubmitEdit. canSend is the gate on the primary send CTA;
 * canSubmitEdit gates the inline 15-min edit confirmation. A regression
 * either bricks both flows or lets blank messages onto the wire.
 */
class ChatUiStateTest {

    @Test fun `title falls back through counterpart, dummyTitle, default`() {
        val withCounterpart = state(
            counterpart = profile(fullName = "Ravi"),
            dummyTitle = "Should not be used",
        )
        assertEquals("Ravi", withCounterpart.title)

        val withDummyOnly = state(dummyTitle = "Engineer Ravi")
        assertEquals("Engineer Ravi", withDummyOnly.title)

        val none = state()
        assertEquals("Chat", none.title)
    }

    @Test fun `canSend requires draft + identity + not sending + not blocked`() {
        val ready = state(selfUserId = "u1", draft = "hi")
        assertTrue(ready.canSend)

        // Blank / whitespace-only drafts block.
        assertFalse(ready.copy(draft = "").canSend)
        assertFalse(ready.copy(draft = "   ").canSend)

        // No self id means we don't know who we are — block.
        assertFalse(ready.copy(selfUserId = null).canSend)

        // Already mid-send.
        assertFalse(ready.copy(sending = true).canSend)

        // Counterpart blocked us (or we blocked them) — can't send.
        assertFalse(ready.copy(counterpartBlocked = true).canSend)
    }

    @Test fun `canSubmitEdit requires an active edit slot and a draft within length cap`() {
        val ready = state(
            editingMessageId = "m1",
            editDraft = "edited body",
            editing = false,
        )
        assertTrue(ready.canSubmitEdit)

        assertFalse(ready.copy(editingMessageId = null).canSubmitEdit)
        assertFalse(ready.copy(editDraft = "").canSubmitEdit)
        assertFalse(ready.copy(editDraft = "   ").canSubmitEdit)
        assertFalse(ready.copy(editing = true).canSubmitEdit)
    }

    @Test fun `canSubmitEdit enforces the 4000-char ceiling`() {
        // Mirrors the server-side `messages.message` length cap.
        val under = state(
            editingMessageId = "m1",
            editDraft = "a".repeat(4000),
        )
        assertTrue(under.canSubmitEdit)

        val over = state(
            editingMessageId = "m1",
            editDraft = "a".repeat(4001),
        )
        assertFalse(over.canSubmitEdit)
    }

    private fun state(
        loading: Boolean = false,
        selfUserId: String? = "self-1",
        counterpart: Profile? = null,
        messages: List<ChatMessage> = emptyList(),
        draft: String = "",
        sending: Boolean = false,
        counterpartBlocked: Boolean = false,
        editingMessageId: String? = null,
        editDraft: String = "",
        editing: Boolean = false,
        dummyTitle: String? = null,
    ) = ChatViewModel.UiState(
        loading = loading,
        selfUserId = selfUserId,
        counterpart = counterpart,
        messages = messages,
        draft = draft,
        sending = sending,
        counterpartBlocked = counterpartBlocked,
        editingMessageId = editingMessageId,
        editDraft = editDraft,
        editing = editing,
        dummyTitle = dummyTitle,
    )

    private fun profile(fullName: String?) = Profile(
        id = "u9",
        email = null,
        phone = null,
        fullName = fullName,
        avatarUrl = null,
        role = null,
        rawRoleKey = null,
        roleConfirmed = true,
        onboardingCompleted = true,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
    )
}
