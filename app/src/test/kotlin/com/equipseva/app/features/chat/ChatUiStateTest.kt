package com.equipseva.app.features.chat

import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the chat-screen derived gates. Three CTA gates this guards:
 *
 *   * `title` — falls back to "Chat" when the counterpart profile
 *     hasn't loaded (race: deep-link straight to chat detail before
 *     the conversation row resolves).
 *   * `canSend` — the primary send-message gate. Must reject blank
 *     drafts, mid-send state, missing self-user-id, and blocked
 *     counterpart. A regression that loosened any of these would
 *     let users push empty / unauthenticated / blocked messages.
 *   * `canSubmitEdit` — the inline-edit gate. Enforces the 4000-char
 *     server max (drafts longer would 413 server-side) + must be
 *     in an editing context (`editingMessageId != null`).
 */
class ChatUiStateTest {

    private fun profile(name: String) = Profile(
        id = "u-other",
        email = null,
        phone = null,
        fullName = name,
        avatarUrl = null,
        role = UserRole.ENGINEER,
        rawRoleKey = "engineer",
        roleConfirmed = true,
        onboardingCompleted = true,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
    )

    // ---- title ----

    @Test fun `title falls back to Chat when counterpart is null`() {
        val state = ChatViewModel.UiState()
        assertEquals("Chat", state.title)
    }

    @Test fun `title uses counterpart displayName when present`() {
        val state = ChatViewModel.UiState(counterpart = profile("Ravi Kumar"))
        assertEquals("Ravi Kumar", state.title)
    }

    // ---- canSend ----

    @Test fun `canSend false when draft is blank`() {
        val state = ChatViewModel.UiState(selfUserId = "u1", draft = "   ")
        assertFalse(state.canSend)
    }

    @Test fun `canSend false when selfUserId is null (not yet signed in)`() {
        val state = ChatViewModel.UiState(selfUserId = null, draft = "hi")
        assertFalse(state.canSend)
    }

    @Test fun `canSend false while sending`() {
        val state = ChatViewModel.UiState(selfUserId = "u1", draft = "hi", sending = true)
        assertFalse(state.canSend)
    }

    @Test fun `canSend false when counterpart is blocked`() {
        // Block-state suppresses the send affordance entirely — the
        // composer renders as a banner with an "Unblock" CTA, not a
        // disabled text field.
        val state = ChatViewModel.UiState(
            selfUserId = "u1",
            draft = "hi",
            counterpartBlocked = true,
        )
        assertFalse(state.canSend)
    }

    @Test fun `canSend true on the happy path`() {
        val state = ChatViewModel.UiState(selfUserId = "u1", draft = "hello")
        assertTrue(state.canSend)
    }

    @Test fun `canSend trims the draft before evaluating non-blank`() {
        val state = ChatViewModel.UiState(selfUserId = "u1", draft = "   hi   ")
        assertTrue(state.canSend)
    }

    // ---- canSubmitEdit ----

    @Test fun `canSubmitEdit false when no message is being edited`() {
        val state = ChatViewModel.UiState(editDraft = "new text")
        assertFalse(state.canSubmitEdit)
    }

    @Test fun `canSubmitEdit false when editDraft is blank`() {
        val state = ChatViewModel.UiState(editingMessageId = "m1", editDraft = "   ")
        assertFalse(state.canSubmitEdit)
    }

    @Test fun `canSubmitEdit false when editing is already in flight`() {
        val state = ChatViewModel.UiState(
            editingMessageId = "m1",
            editDraft = "new text",
            editing = true,
        )
        assertFalse(state.canSubmitEdit)
    }

    @Test fun `canSubmitEdit false when editDraft exceeds 4000 chars`() {
        // Server max is 4000; client must short-circuit so the user
        // doesn't see a "submission failed" toast on a hard length cap.
        val state = ChatViewModel.UiState(
            editingMessageId = "m1",
            editDraft = "a".repeat(4001),
        )
        assertFalse(state.canSubmitEdit)
    }

    @Test fun `canSubmitEdit true at exactly 4000 chars`() {
        val state = ChatViewModel.UiState(
            editingMessageId = "m1",
            editDraft = "a".repeat(4000),
        )
        assertTrue(state.canSubmitEdit)
    }
}
