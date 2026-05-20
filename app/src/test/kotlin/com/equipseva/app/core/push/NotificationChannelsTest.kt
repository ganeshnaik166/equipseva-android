package com.equipseva.app.core.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The four channel ids are shared with the server-side push payload
 * (`channel` JSON field on every `send_push_notification` emit). A
 * client-side rename without a coordinated server change drops every
 * push of that category on the floor — Android silently routes the
 * incoming payload to the OS-default "uncategorized" channel which
 * the per-category mute switch can't gate.
 */
class NotificationChannelsTest {

    @Test fun `channel ids match the server-side push payload contract`() {
        assertEquals("orders", NotificationChannels.ORDERS)
        assertEquals("jobs", NotificationChannels.JOBS)
        assertEquals("chat", NotificationChannels.CHAT)
        assertEquals("account", NotificationChannels.ACCOUNT)
    }

    @Test fun `channel ids are unique`() {
        val ids = listOf(
            NotificationChannels.ORDERS,
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT,
        )
        assertEquals(ids.size, ids.distinct().size)
    }

    @Test fun `channel ids are lowercase snake-friendly and trimmed`() {
        // The per-category mute switch persists these ids to DataStore as a
        // string-set; a trailing space or uppercase would silently desync
        // from the runtime channel registration.
        listOf(
            NotificationChannels.ORDERS,
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT,
        ).forEach { id ->
            assertEquals(id.lowercase(), id)
            assertEquals(id.trim(), id)
            assertTrue("non-empty id required", id.isNotEmpty())
        }
    }
}
