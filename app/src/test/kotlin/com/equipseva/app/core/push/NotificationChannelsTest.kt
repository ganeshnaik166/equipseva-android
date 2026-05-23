package com.equipseva.app.core.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the notification-channel ID constants. The server-side push
 * payload encodes the same string verbatim into the FCM message's
 * `notification.channel_id` so the Android notification surface knows
 * which user-visible category to route the alert into. A rename here
 * (e.g. "jobs" → "job") without a matching server-side rollout would
 * silently dump every job push into the legacy / default channel.
 *
 * Caught here so this contract is preserved.
 */
class NotificationChannelsTest {

    @Test fun `JOBS channel id is the literal string jobs`() {
        assertEquals("jobs", NotificationChannels.JOBS)
    }

    @Test fun `CHAT channel id is the literal string chat`() {
        assertEquals("chat", NotificationChannels.CHAT)
    }

    @Test fun `ACCOUNT channel id is the literal string account`() {
        assertEquals("account", NotificationChannels.ACCOUNT)
    }

    @Test fun `each channel has a distinct id`() {
        val ids = listOf(
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT,
        )
        assertEquals(ids.size, ids.toSet().size)
    }

    @Test fun `legacy orders channel id is not in the active set`() {
        // The "orders" marketplace channel was retired in v1 and is
        // explicitly deleted from the NotificationManager on register().
        // Pin so a future re-add (without retiring it from `register`)
        // is intentional rather than a silent ressurection.
        assertNotEquals("orders", NotificationChannels.JOBS)
        assertNotEquals("orders", NotificationChannels.CHAT)
        assertNotEquals("orders", NotificationChannels.ACCOUNT)
    }

    @Test fun `channel ids are lowercase ascii (no whitespace, no caps)`() {
        // FCM treats channel_id case-sensitively; keep them lowercase
        // ascii to match the server-side push trigger string literals.
        val all = listOf(
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT,
        )
        all.forEach { id ->
            assertTrue("$id contains uppercase", id == id.lowercase())
            assertTrue("$id contains whitespace", id.none { it.isWhitespace() })
            assertTrue("$id is empty", id.isNotEmpty())
        }
    }
}
