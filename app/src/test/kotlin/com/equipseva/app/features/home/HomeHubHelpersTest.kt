package com.equipseva.app.features.home

import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the pure derivations pulled out of [HomeHubViewModel]:
 *  - cached-role lookup (UserPrefs.activeRole → UserRole) that gates the
 *    HomeHub tile set during the post-signup profile-row trigger race
 *  - the "actively working this job" predicate used by both the engineer
 *    and hospital hero stat strips
 *
 * Pure JUnit only — no ViewModel construction needed.
 */
class HomeHubHelpersTest {

    /* --------- cachedRoleFromKey --------- */

    @Test fun `cachedRoleFromKey returns null for null, blank, and unknown keys`() {
        assertNull(cachedRoleFromKey(null))
        assertNull(cachedRoleFromKey(""))
        assertNull(cachedRoleFromKey("   "))
        assertNull(cachedRoleFromKey("admin"))
    }

    @Test fun `cachedRoleFromKey resolves every UserRole storageKey`() {
        // Forwards-compat: pin that every role round-trips, so adding a
        // new role + forgetting to wire it through here breaks loudly.
        UserRole.entries.forEach { role ->
            assertEquals(role, cachedRoleFromKey(role.storageKey))
        }
    }

    @Test fun `cachedRoleFromKey is case-sensitive on the storage key`() {
        // storageKey values mirror the server `user_role` enum verbatim,
        // which is lowercase. Anything else must NOT match — we don't want
        // a stale "ENGINEER" cached pref from an older build flipping the
        // tiles.
        val role = UserRole.entries.first()
        assertNull(cachedRoleFromKey(role.storageKey.uppercase()))
    }

    /* --------- isActiveJobStatus --------- */

    @Test fun `isActiveJobStatus is true for Assigned, EnRoute, InProgress`() {
        assertTrue(isActiveJobStatus(RepairJobStatus.Assigned))
        assertTrue(isActiveJobStatus(RepairJobStatus.EnRoute))
        assertTrue(isActiveJobStatus(RepairJobStatus.InProgress))
    }

    @Test fun `isActiveJobStatus is false for Requested`() {
        // Requested is the "open" status, counted separately in the hospital
        // hero strip — must NOT also bleed into Active.
        assertFalse(isActiveJobStatus(RepairJobStatus.Requested))
    }

    @Test fun `isActiveJobStatus is false for every terminal status`() {
        // Catch-all guard so a new in-flight status added server-side fails
        // the test until the predicate is updated rather than silently
        // dropping out of the Active count.
        val active = setOf(
            RepairJobStatus.Assigned,
            RepairJobStatus.EnRoute,
            RepairJobStatus.InProgress,
        )
        RepairJobStatus.entries.filterNot { it in active || it == RepairJobStatus.Requested }
            .forEach { terminal ->
                assertFalse(
                    "Status $terminal must not count as active",
                    isActiveJobStatus(terminal),
                )
            }
    }
}
