package com.equipseva.app.features.notifications

import com.equipseva.app.core.push.NotificationChannels
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-role push-category-toggle assembly. Three rows always:
 * Jobs, Chat, Account & security. The Jobs row label flips between
 * "Booking updates" (hospital perspective) and "Available jobs"
 * (engineer perspective) — same FCM channel, two reading frames.
 *
 * Also pins that the v1 "Order updates" category is NOT in the list —
 * v1 has no marketplace, so surfacing the toggle would let users mute
 * a category that never fires.
 */
class BuildCategoriesTest {

    // ---- shape ----

    @Test fun `produces exactly three rows (Jobs Chat Account)`() {
        val rows = buildCategories(muted = emptySet(), role = null)
        assertEquals(3, rows.size)
        assertEquals(NotificationChannels.JOBS, rows[0].channelId)
        assertEquals(NotificationChannels.CHAT, rows[1].channelId)
        assertEquals(NotificationChannels.ACCOUNT, rows[2].channelId)
    }

    @Test fun `Order updates marketplace channel is intentionally absent`() {
        val rows = buildCategories(muted = emptySet(), role = UserRole.HOSPITAL)
        assertFalse(
            "no row should reference the legacy orders channel",
            rows.any { it.channelId == "orders" || it.label.contains("Order", ignoreCase = true) },
        )
    }

    // ---- hospital framing ----

    @Test fun `hospital role flips Jobs row label and description to booking framing`() {
        val rows = buildCategories(muted = emptySet(), role = UserRole.HOSPITAL)
        val jobs = rows.first { it.channelId == NotificationChannels.JOBS }
        assertEquals("Booking updates", jobs.label)
        assertEquals("Bids received, engineer assigned, dispute updates", jobs.description)
    }

    @Test fun `engineer role uses the bid-feed framing on the Jobs row`() {
        val rows = buildCategories(muted = emptySet(), role = UserRole.ENGINEER)
        val jobs = rows.first { it.channelId == NotificationChannels.JOBS }
        assertEquals("Available jobs", jobs.label)
        assertEquals("New repair jobs and bid responses", jobs.description)
    }

    @Test fun `null role falls back to engineer framing (safe default for signed-out preview)`() {
        val rows = buildCategories(muted = emptySet(), role = null)
        val jobs = rows.first { it.channelId == NotificationChannels.JOBS }
        assertEquals("Available jobs", jobs.label)
    }

    @Test fun `other roles use the engineer framing`() {
        // Supplier / manufacturer / logistics share the engineer
        // copy — they all receive jobs / bid pushes, not buyer copy.
        listOf(UserRole.SUPPLIER, UserRole.MANUFACTURER, UserRole.LOGISTICS).forEach { role ->
            val jobs = buildCategories(emptySet(), role)
                .first { it.channelId == NotificationChannels.JOBS }
            assertEquals("expected engineer framing for $role", "Available jobs", jobs.label)
        }
    }

    // ---- chat + account row copy (role-agnostic) ----

    @Test fun `Chat row copy is role-agnostic`() {
        val hospital = buildCategories(emptySet(), UserRole.HOSPITAL)
            .first { it.channelId == NotificationChannels.CHAT }
        val engineer = buildCategories(emptySet(), UserRole.ENGINEER)
            .first { it.channelId == NotificationChannels.CHAT }
        assertEquals(hospital.label, engineer.label)
        assertEquals(hospital.description, engineer.description)
        assertEquals("Chat messages", hospital.label)
    }

    @Test fun `Account row copy is role-agnostic`() {
        val rows = buildCategories(emptySet(), UserRole.HOSPITAL)
        val acct = rows.first { it.channelId == NotificationChannels.ACCOUNT }
        assertEquals("Account & security", acct.label)
        assertEquals("Verification, KYC, security alerts", acct.description)
    }

    // ---- muted flag ----

    @Test fun `muted set drives the muted boolean per row`() {
        val rows = buildCategories(
            muted = setOf(NotificationChannels.JOBS),
            role = UserRole.ENGINEER,
        )
        assertTrue(rows.first { it.channelId == NotificationChannels.JOBS }.muted)
        assertFalse(rows.first { it.channelId == NotificationChannels.CHAT }.muted)
        assertFalse(rows.first { it.channelId == NotificationChannels.ACCOUNT }.muted)
    }

    @Test fun `empty muted set marks every row unmuted`() {
        buildCategories(emptySet(), UserRole.HOSPITAL).forEach { row ->
            assertFalse("${row.channelId} should be unmuted", row.muted)
        }
    }

    @Test fun `all-muted set marks every row muted`() {
        val all = setOf(
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT,
        )
        buildCategories(all, UserRole.HOSPITAL).forEach { row ->
            assertTrue("${row.channelId} should be muted", row.muted)
        }
    }

    @Test fun `stale muted entry from a removed channel does not surface as a phantom row`() {
        // If the user previously muted the legacy "orders" channel and
        // then upgraded, the row list must not regrow to include it.
        val rows = buildCategories(setOf("orders"), UserRole.HOSPITAL)
        assertEquals(3, rows.size)
        assertFalse(rows.any { it.channelId == "orders" })
    }
}
