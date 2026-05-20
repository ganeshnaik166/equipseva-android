package com.equipseva.app.features.notifications

import com.equipseva.app.core.data.notifications.Notification
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * Pins the two derived properties on NotificationsInboxViewModel.UiState
 * — unreadCount and hasUnread. The inbox app-bar badge + the "Mark all
 * read" CTA both key off these, so an off-by-one would either hide the
 * action when there's work to do or show a stale "(0)" badge.
 */
class NotificationsInboxUiStateTest {

    @Test fun `unreadCount on empty inbox is zero`() {
        val s = NotificationsInboxViewModel.UiState(rows = emptyList())
        assertEquals(0, s.unreadCount)
        assertFalse(s.hasUnread)
    }

    @Test fun `unreadCount counts only rows with null readAt`() {
        val s = NotificationsInboxViewModel.UiState(
            rows = listOf(
                row("a", unread = true),
                row("b", unread = false),
                row("c", unread = true),
                row("d", unread = false),
            ),
        )
        assertEquals(2, s.unreadCount)
        assertTrue(s.hasUnread)
    }

    @Test fun `hasUnread is false when every row is read`() {
        // After "Mark all read" the bulk CTA must disappear — that flow
        // depends on hasUnread flipping to false in the same emission.
        val s = NotificationsInboxViewModel.UiState(
            rows = listOf(row("a", unread = false), row("b", unread = false)),
        )
        assertEquals(0, s.unreadCount)
        assertFalse(s.hasUnread)
    }

    @Test fun `hasUnread is true when at least one row is unread`() {
        val s = NotificationsInboxViewModel.UiState(
            rows = listOf(row("a", unread = false), row("b", unread = true)),
        )
        assertEquals(1, s.unreadCount)
        assertTrue(s.hasUnread)
    }

    @Test fun `default UiState is loading with empty inbox and no error`() {
        // The screen renders a skeleton on the loading=true + empty rows
        // combination; a regression that flipped the default would briefly
        // show "You're all caught up" before the first realtime emission.
        val s = NotificationsInboxViewModel.UiState()
        assertTrue(s.loading)
        assertFalse(s.refreshing)
        assertTrue(s.rows.isEmpty())
        assertEquals(null, s.errorMessage)
        assertEquals(0, s.unreadCount)
        assertFalse(s.hasUnread)
    }

    private fun row(id: String, unread: Boolean): Notification = Notification(
        id = id,
        userId = "u1",
        title = "t",
        body = "b",
        kind = null,
        data = emptyMap(),
        sentAt = Instant.EPOCH,
        readAt = if (unread) null else Instant.EPOCH.plusSeconds(60),
        deepLink = null,
    )
}
