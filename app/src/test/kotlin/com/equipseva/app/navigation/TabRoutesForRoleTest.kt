package com.equipseva.app.navigation

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-role bottom-nav tab arrangement:
 *
 *   * Hospital → 4 tabs: Home / Bookings / Messages / Profile
 *   * Engineer → 4 tabs: Home / Jobs / Earnings / Profile
 *   * Null or deferred role → no tabs; root requires a supported role.
 *
 * Two regressions worth defending:
 *   1) The Hospital tab list MUST be 4 entries (Home / Bookings /
 *      Messages / Profile) — Messages is a real tab, not relegated to
 *      a Home card or Profile row. v0.3.4 ships this change.
 *   2) The Jobs tab routes to ENGINEER_JOBS_HUB (chooser landing),
 *      not REPAIR (raw feed). Hub then routes into the feed via the
 *      "Available jobs" tile. Pin so a refactor that "simplifies" by
 *      routing straight to REPAIR doesn't slip past review.
 */
class TabRoutesForRoleTest {

    @Test fun `Hospital role gets four tabs with Messages before Profile`() {
        val tabs = tabRoutesForRole(UserRole.HOSPITAL)
        assertEquals(
            listOf(Routes.HOME, Routes.HOSPITAL_ACTIVE_JOBS, Routes.CONVERSATIONS, Routes.PROFILE),
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

    @Test fun `null role has no privileged tab fallback`() {
        assertEquals(emptyList<String>(), tabRoutesForRole(null))
    }

    @Test fun `deferred roles have no engineer tab fallback`() {
        listOf(UserRole.SUPPLIER, UserRole.MANUFACTURER, UserRole.LOGISTICS).forEach { role ->
            assertEquals(
                "expected no supported tab surface for $role",
                emptyList<String>(),
                tabRoutesForRole(role),
            )
        }
    }

    @Test fun `Hospital tab list is exactly 4 entries Home Bookings Messages Profile`() {
        assertEquals(4, tabRoutesForRole(UserRole.HOSPITAL).size)
    }

    @Test fun `every supported role's tab list starts at HOME`() {
        listOf(UserRole.HOSPITAL, UserRole.ENGINEER).forEach { role ->
            assertEquals(
                "expected first tab to be HOME for $role",
                Routes.HOME,
                tabRoutesForRole(role).first(),
            )
        }
    }

    @Test fun `every supported role's tab list ends at PROFILE`() {
        listOf(UserRole.HOSPITAL, UserRole.ENGINEER).forEach { role ->
            assertEquals(
                "expected last tab to be PROFILE for $role",
                Routes.PROFILE,
                tabRoutesForRole(role).last(),
            )
        }
    }
}
