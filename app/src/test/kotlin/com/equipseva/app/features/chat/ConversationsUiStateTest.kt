package com.equipseva.app.features.chat

import com.equipseva.app.core.data.chat.ChatConversation
import com.equipseva.app.core.data.profile.Profile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two derived properties on ConversationsViewModel — the row's
 * title + preview fallback chain, and the UiState.displayedRows search
 * filter the Conversations search bar (PR #174) reads.
 */
class ConversationsUiStateTest {

    @Test fun `Row title falls through counterpart, dummyTitle, default`() {
        val convo = conversation()

        assertEquals(
            "Ravi",
            ConversationsViewModel.Row(convo, counterpart = profile("Ravi")).title,
        )
        assertEquals(
            "Engineer Ravi",
            ConversationsViewModel.Row(
                convo,
                counterpart = null,
                dummyTitle = "Engineer Ravi",
            ).title,
        )
        assertEquals(
            "Conversation",
            ConversationsViewModel.Row(convo, counterpart = null).title,
        )
    }

    @Test fun `Row preview falls through last_message or shows placeholder`() {
        val withMsg = ConversationsViewModel.Row(
            conversation = conversation(lastMessage = "On my way"),
            counterpart = profile("Ravi"),
        )
        assertEquals("On my way", withMsg.preview)

        val blankMsg = ConversationsViewModel.Row(
            conversation = conversation(lastMessage = "   "),
            counterpart = profile("Ravi"),
        )
        assertEquals("No messages yet", blankMsg.preview)

        val noMsg = ConversationsViewModel.Row(
            conversation = conversation(lastMessage = null),
            counterpart = profile("Ravi"),
        )
        assertEquals("No messages yet", noMsg.preview)
    }

    @Test fun `displayedRows returns all rows when query is blank`() {
        val rows = listOf(
            row(title = "Ravi", message = "hi"),
            row(title = "Priya", message = "bye"),
        )
        val state = ConversationsViewModel.UiState(rows = rows)
        assertEquals(rows, state.displayedRows)

        // Whitespace-only query also doesn't filter.
        assertEquals(rows, state.copy(query = "   ").displayedRows)
    }

    @Test fun `displayedRows matches against title and preview, case-insensitive`() {
        val ravi = row(title = "Ravi", message = "on my way")
        val priya = row(title = "Priya", message = "bringing the part")
        val rows = listOf(ravi, priya)
        val state = ConversationsViewModel.UiState(rows = rows)

        assertEquals(listOf(ravi), state.copy(query = "ravi").displayedRows)
        assertEquals(listOf(ravi), state.copy(query = "RAVI").displayedRows)
        assertEquals(listOf(priya), state.copy(query = "Bringing").displayedRows)
        // Match against the preview line, not just the title.
        assertEquals(listOf(ravi), state.copy(query = "on my way").displayedRows)
        assertTrue(state.copy(query = "totally-not-there").displayedRows.isEmpty())
    }

    @Test fun `displayedRows trims surrounding whitespace from the query`() {
        val ravi = row(title = "Ravi", message = "hi")
        val state = ConversationsViewModel.UiState(rows = listOf(ravi), query = "  ravi  ")
        assertEquals(listOf(ravi), state.displayedRows)
    }

    private fun conversation(lastMessage: String? = "hi") = ChatConversation(
        id = "conv-1",
        participantUserIds = listOf("u1", "u2"),
        relatedEntityType = null,
        relatedEntityId = null,
        lastMessage = lastMessage,
        lastMessageAtIso = null,
        createdAtIso = null,
    )

    private fun row(title: String, message: String) = ConversationsViewModel.Row(
        conversation = conversation(lastMessage = message),
        counterpart = profile(title),
    )

    private fun profile(name: String) = Profile(
        id = "u9",
        email = null,
        phone = null,
        fullName = name,
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
