package com.equipseva.app.features.notifications

import com.equipseva.app.core.data.notifications.Notification
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * Pins the derived `unreadCount` + `hasUnread` getters on the inbox
 * UiState. The bottom-nav unread-dot badge is driven by `hasUnread`;
 * the inbox header chip surfaces `unreadCount`. A regression that
 * miscounts would either over-promote a clean inbox to "1 unread" or
 * silently swallow real unread rows.
 */
class NotificationsInboxUiStateTest {

    private fun row(id: String, readAt: Instant? = null) = Notification(
        id = id,
        title = "t",
        body = "b",
        kind = null,
        data = emptyMap(),
        sentAt = Instant.parse("2026-05-21T10:00:00Z"),
        readAt = readAt,
        deepLink = null,
    )

    @Test fun `empty rows yields zero unread and hasUnread false`() {
        val state = NotificationsInboxViewModel.UiState()
        assertEquals(0, state.unreadCount)
        assertFalse(state.hasUnread)
    }

    @Test fun `all read rows yields zero unread and hasUnread false`() {
        val now = Instant.parse("2026-05-21T11:00:00Z")
        val state = NotificationsInboxViewModel.UiState(
            loading = false,
            rows = listOf(row("a", readAt = now), row("b", readAt = now)),
        )
        assertEquals(0, state.unreadCount)
        assertFalse(state.hasUnread)
    }

    @Test fun `mixed rows yields correct unread count and hasUnread true`() {
        val now = Instant.parse("2026-05-21T11:00:00Z")
        val state = NotificationsInboxViewModel.UiState(
            loading = false,
            rows = listOf(
                row("a", readAt = now),
                row("b", readAt = null),
                row("c", readAt = null),
                row("d", readAt = now),
            ),
        )
        assertEquals(2, state.unreadCount)
        assertTrue(state.hasUnread)
    }

    @Test fun `all unread yields full count`() {
        val state = NotificationsInboxViewModel.UiState(
            loading = false,
            rows = listOf(row("a"), row("b"), row("c")),
        )
        assertEquals(3, state.unreadCount)
        assertTrue(state.hasUnread)
    }
}
