package com.equipseva.app.navigation

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-role bottom-nav tab arrangement:
 *
 *   * Hospital → 3 tabs: Home / Bookings / Profile
 *   * Engineer (and every other / null role) → 4 tabs: Home / Jobs /
 *     Earnings / Profile
 *
 * Two regressions worth defending:
 *   1) The Hospital tab list MUST be 3 entries — 4 entries would
 *      surface the engineer "Earnings" tab to hospitals (no rows,
 *      empty state, leaks role intent).
 *   2) The Jobs tab routes to ENGINEER_JOBS_HUB (chooser landing),
 *      not REPAIR (raw feed). Hub then routes into the feed via the
 *      "Available jobs" tile. Pin so a refactor that "simplifies" by
 *      routing straight to REPAIR doesn't slip past review.
 */
class TabRoutesForRoleTest {

    @Test fun `Hospital role gets three tabs ending at Profile`() {
        val tabs = tabRoutesForRole(UserRole.HOSPITAL)
        assertEquals(
            listOf(Routes.HOME, Routes.HOSPITAL_ACTIVE_JOBS, Routes.PROFILE),
            tabs,
        )
    }

    @Test fun `Engineer role gets four tabs with Jobs and Earnings`() {
        val tabs = tabRoutesForRole(UserRole.ENGINEER)
        assertEquals(
            listOf(
                Routes.HOME,
                Routes.ENGINEER_JOBS_HUB,
                Routes.EARNINGS,
                Routes.PROFILE,
            ),
            tabs,
        )
    }

    @Test fun `Jobs tab routes to ENGINEER_JOBS_HUB not the raw REPAIR feed`() {
        val tabs = tabRoutesForRole(UserRole.ENGINEER)
        assertTrue(
            "expected ENGINEER_JOBS_HUB in engineer tabs",
            tabs.contains(Routes.ENGINEER_JOBS_HUB),
        )
        // REPAIR is the raw feed — only the hub should appear in the
        // bottom nav; the hub tile then routes into REPAIR.
        assertTrue(
            "REPAIR must NOT surface as a bottom-nav tab",
            !tabs.contains(Routes.REPAIR),
        )
    }

    @Test fun `null role falls back to engineer tabs (anonymous default)`() {
        // Loading state — the bottom nav must still render something
        // so the user has affordances; default to engineer's 4-tab
        // layout per the file comment.
        assertEquals(
            listOf(
                Routes.HOME,
                Routes.ENGINEER_JOBS_HUB,
                Routes.EARNINGS,
                Routes.PROFILE,
            ),
            tabRoutesForRole(null),
        )
    }

    @Test fun `non-hospital non-engineer roles all use the engineer 4-tab layout`() {
        // Supplier / Manufacturer / Logistics — they all see the same
        // engineer tabs in v1 (their dedicated surfaces ship in v2).
        // Pin so a future addition without a role-specific tab list
        // surfaces.
        listOf(UserRole.SUPPLIER, UserRole.MANUFACTURER, UserRole.LOGISTICS).forEach { role ->
            assertEquals(
                "expected engineer tabs for $role",
                4,
                tabRoutesForRole(role).size,
            )
        }
    }

    @Test fun `Hospital tab list is exactly 3 entries (no engineer Earnings leak)`() {
        assertEquals(3, tabRoutesForRole(UserRole.HOSPITAL).size)
    }

    @Test fun `every role's tab list starts at HOME`() {
        UserRole.entries.forEach { role ->
            assertEquals(
                "expected first tab to be HOME for $role",
                Routes.HOME,
                tabRoutesForRole(role).first(),
            )
        }
    }

    @Test fun `every role's tab list ends at PROFILE`() {
        UserRole.entries.forEach { role ->
            assertEquals(
                "expected last tab to be PROFILE for $role",
                Routes.PROFILE,
                tabRoutesForRole(role).last(),
            )
        }
    }
}
