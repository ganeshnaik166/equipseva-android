package com.equipseva.app.features.home

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the role-aware empty-state copy for Home's "Recent activity"
 * section.
 *
 * Pinned regression: an earlier version surfaced the same generic
 * "Your bookings, bids, and messages will appear here." for every
 * role. That stated the obvious without telling the user how to get
 * unstuck. Role-aware copy points at the next CTA (Hospital → Book,
 * Engineer → Jobs tab).
 */
class HomeRecentEmptyCopyTest {

    @Test fun `Hospital points at the Book CTA`() {
        val copy = homeRecentEmptyCopy(UserRole.HOSPITAL)
        assertEquals(
            "No bookings yet. Tap \"Book a repair engineer\" above to post your first job.",
            copy,
        )
    }

    @Test fun `Engineer points at the Jobs tab`() {
        val copy = homeRecentEmptyCopy(UserRole.ENGINEER)
        assertEquals(
            "No activity yet. Tap the Jobs tab to find open repair jobs you can bid on.",
            copy,
        )
    }

    @Test fun `null role uses the generic fallback`() {
        val copy = homeRecentEmptyCopy(null)
        assertEquals(
            "Your bookings, bids, and messages will appear here.",
            copy,
        )
    }

    @Test fun `Supplier role uses the generic fallback`() {
        // Marketplace roles share the generic copy (their dedicated
        // surfaces don't ship in v1). Pin so a future role-specific
        // CTA addition surfaces.
        assertEquals(
            "Your bookings, bids, and messages will appear here.",
            homeRecentEmptyCopy(UserRole.SUPPLIER),
        )
    }

    @Test fun `Manufacturer + Logistics also use the generic fallback`() {
        assertEquals(
            "Your bookings, bids, and messages will appear here.",
            homeRecentEmptyCopy(UserRole.MANUFACTURER),
        )
        assertEquals(
            "Your bookings, bids, and messages will appear here.",
            homeRecentEmptyCopy(UserRole.LOGISTICS),
        )
    }

    @Test fun `Hospital + Engineer copy each mention a distinct next action`() {
        // Pin so a future refactor doesn't accidentally swap or
        // collapse the two CTAs — the words "Book" / "Jobs tab" are
        // the affordance signal.
        val hospital = homeRecentEmptyCopy(UserRole.HOSPITAL)
        val engineer = homeRecentEmptyCopy(UserRole.ENGINEER)
        assertEquals(true, hospital.contains("Book"))
        assertEquals(true, engineer.contains("Jobs tab"))
        assertEquals(true, hospital != engineer)
    }

    @Test fun `every role yields non-blank copy (defensive)`() {
        UserRole.entries.forEach { role ->
            val copy = homeRecentEmptyCopy(role)
            assertEquals("$role should have non-blank copy", true, copy.isNotBlank())
        }
        assertEquals(true, homeRecentEmptyCopy(null).isNotBlank())
    }
}
