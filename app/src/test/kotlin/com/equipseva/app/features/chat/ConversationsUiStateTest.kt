package com.equipseva.app.features.chat

import com.equipseva.app.core.data.chat.ChatConversation
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * Pins the [ConversationsViewModel.UiState] derivations:
 *
 *   * `Row.title` — falls back to "Conversation" when the
 *     counterpart profile hasn't loaded (race: realtime conversation
 *     arrives before the joined profile query returns).
 *   * `Row.preview` — falls back to "No messages yet" on a brand-new
 *     conversation row.
 *   * `displayedRows` — the inbox-search filter. Searches both the
 *     title and the preview text, case-insensitive, with the query
 *     trimmed. An empty / blank query short-circuits to the full
 *     unfiltered list (important for performance on long inboxes).
 */
class ConversationsUiStateTest {

    private fun conv(
        id: String,
        lastMessage: String?,
    ) = ChatConversation(
        id = id,
        participantUserIds = listOf("u-self", "u-other"),
        relatedEntityType = null,
        relatedEntityId = null,
        lastMessage = lastMessage,
        lastMessageAtIso = null,
        createdAtIso = null,
    )

    private fun profile(displayName: String): Profile = Profile(
        id = "u-other",
        email = null,
        phone = null,
        fullName = displayName,
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

    // ---- Row.title / Row.preview ----

    @Test fun `title falls back to Conversation when counterpart is null`() {
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = "hi"),
            counterpart = null,
        )
        assertEquals("Conversation", row.title)
    }

    @Test fun `title uses counterpart displayName when present`() {
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = "hi"),
            counterpart = profile("Ravi Kumar"),
        )
        assertEquals("Ravi Kumar", row.title)
    }

    @Test fun `preview falls back to no-messages copy on null lastMessage`() {
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = null),
            counterpart = null,
        )
        assertEquals("No messages yet", row.preview)
    }

    @Test fun `preview falls back on blank lastMessage too`() {
        // Server-side last_message can be a single newline / whitespace
        // after an edit. UX hides those rather than rendering a blank
        // bubble line under the title.
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = "   "),
            counterpart = null,
        )
        assertEquals("No messages yet", row.preview)
    }

    @Test fun `preview echoes lastMessage when non-blank`() {
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = "On my way"),
            counterpart = null,
        )
        assertEquals("On my way", row.preview)
    }

    // ---- displayedRows ----

    private fun row(id: String, name: String, message: String?) = ConversationsViewModel.Row(
        conversation = conv(id, message),
        counterpart = profile(name),
    )

    @Test fun `displayedRows returns full list when query is blank`() {
        val rows = listOf(
            row("c1", "Ravi Kumar", "ETA 30 min"),
            row("c2", "Anjali Patel", "Done"),
        )
        val state = ConversationsViewModel.UiState(loading = false, rows = rows, query = "   ")
        // Same identity, not just same content — short-circuit return.
        assertSame(rows, state.displayedRows)
    }

    @Test fun `displayedRows filters case-insensitively on title`() {
        val rows = listOf(
            row("c1", "Ravi Kumar", "ETA 30 min"),
            row("c2", "Anjali Patel", "Done"),
        )
        val state = ConversationsViewModel.UiState(loading = false, rows = rows, query = "RAVI")
        assertEquals(listOf("c1"), state.displayedRows.map { it.conversation.id })
    }

    @Test fun `displayedRows filters on preview text too`() {
        val rows = listOf(
            row("c1", "Ravi Kumar", "ETA 30 min"),
            row("c2", "Anjali Patel", "Done"),
        )
        val state = ConversationsViewModel.UiState(loading = false, rows = rows, query = "Done")
        assertEquals(listOf("c2"), state.displayedRows.map { it.conversation.id })
    }

    @Test fun `displayedRows trims query whitespace`() {
        val rows = listOf(
            row("c1", "Ravi Kumar", "ETA 30 min"),
            row("c2", "Anjali Patel", "Done"),
        )
        val state = ConversationsViewModel.UiState(loading = false, rows = rows, query = "  Done  ")
        assertEquals(listOf("c2"), state.displayedRows.map { it.conversation.id })
    }

    @Test fun `displayedRows yields empty list when no match`() {
        val rows = listOf(
            row("c1", "Ravi Kumar", "ETA 30 min"),
        )
        val state = ConversationsViewModel.UiState(loading = false, rows = rows, query = "xyz")
        assertEquals(emptyList<ConversationsViewModel.Row>(), state.displayedRows)
    }

    @Test fun `displayedRows matches against fallback title and preview copy`() {
        // A row without a counterpart profile still has the fallback
        // "Conversation" title — searching for "Conversation" should
        // pick it up.
        val row = ConversationsViewModel.Row(
            conversation = conv("c1", lastMessage = null),
            counterpart = null,
        )
        val state = ConversationsViewModel.UiState(
            loading = false,
            rows = listOf(row),
            query = "Conversation",
        )
        assertEquals(1, state.displayedRows.size)
    }
}
