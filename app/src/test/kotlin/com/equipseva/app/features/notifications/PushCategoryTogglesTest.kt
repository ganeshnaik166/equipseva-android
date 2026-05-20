package com.equipseva.app.features.notifications

import com.equipseva.app.core.push.NotificationChannels
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins buildPushCategoryToggles — the pure helper behind
 * NotificationSettingsViewModel.categories. Two things matter:
 *   1. Order + identity of the three v1 channels (no ORDERS — marketplace
 *      is deferred to v2 and the toggle would mute a category that never
 *      fires).
 *   2. The `muted` flag mirrors set membership exactly, so toggling the
 *      DataStore set immediately drives the row's switch state.
 */
class PushCategoryTogglesTest {

    @Test fun `empty muted set yields three rows in the canonical jobs-chat-account order`() {
        val rows = buildPushCategoryToggles(emptySet())
        assertEquals(3, rows.size)
        assertEquals(
            listOf(NotificationChannels.JOBS, NotificationChannels.CHAT, NotificationChannels.ACCOUNT),
            rows.map { it.channelId },
        )
        // None muted when set is empty.
        assertTrue(rows.none { it.muted })
    }

    @Test fun `Orders channel is intentionally absent`() {
        // v1 has no orders/cart/checkout surface; showing the toggle would
        // let users mute a category that never delivers. Even if ORDERS is
        // somehow present in the muted set, the helper must not surface it.
        val rows = buildPushCategoryToggles(setOf(NotificationChannels.ORDERS))
        assertFalse(rows.any { it.channelId == NotificationChannels.ORDERS })
    }

    @Test fun `each channel id flips its own muted flag without leaking to siblings`() {
        val muted = buildPushCategoryToggles(setOf(NotificationChannels.JOBS))
        assertTrue(muted.first { it.channelId == NotificationChannels.JOBS }.muted)
        assertFalse(muted.first { it.channelId == NotificationChannels.CHAT }.muted)
        assertFalse(muted.first { it.channelId == NotificationChannels.ACCOUNT }.muted)
    }

    @Test fun `all three muted when all three channel ids are in the set`() {
        val rows = buildPushCategoryToggles(
            setOf(NotificationChannels.JOBS, NotificationChannels.CHAT, NotificationChannels.ACCOUNT),
        )
        assertTrue(rows.all { it.muted })
    }

    @Test fun `unknown channel ids in muted set are ignored`() {
        // Forward-compat: server may add a new category before the app
        // ships a UI row for it. The helper must silently skip it instead
        // of crashing or surfacing a phantom row.
        val rows = buildPushCategoryToggles(setOf("future_v2_marketing"))
        assertEquals(3, rows.size)
        assertTrue(rows.none { it.muted })
    }

    @Test fun `labels and descriptions are stable strings the screen reads verbatim`() {
        // Strings are user-visible and assumed-stable by analytics; pin
        // them so a rename triggers a deliberate failure.
        val rows = buildPushCategoryToggles(emptySet()).associateBy { it.channelId }
        val jobs = rows.getValue(NotificationChannels.JOBS)
        assertEquals("Available jobs", jobs.label)
        assertEquals("New repair jobs and bid responses", jobs.description)
        val chat = rows.getValue(NotificationChannels.CHAT)
        assertEquals("Chat messages", chat.label)
        val account = rows.getValue(NotificationChannels.ACCOUNT)
        assertEquals("Account & security", account.label)
    }
}
