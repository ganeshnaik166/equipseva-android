package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the role-picker tile copy + the active/inactive split. The
 * picker shows every UserRole entry but only HOSPITAL + ENGINEER are
 * clickable in v1 — the rest carry a "Soon" pill and have to stay
 * disabled. If this drift lands a SUPPLIER user mid-onboarding the
 * follow-up screens have nothing to render and the app dead-ends.
 *
 * The copy strings double as accessibility labels (a11y readers
 * announce the label + desc), so a typo here is also an a11y bug.
 */
class RoleTileTextTest {

    @Test fun `hospital tile is active with picker copy`() {
        val t = roleTileText(UserRole.HOSPITAL)
        assertEquals("Hospital admin", t.label)
        assertEquals("Book engineers for your facility", t.desc)
        assertTrue(t.active)
    }

    @Test fun `engineer tile is active with picker copy`() {
        val t = roleTileText(UserRole.ENGINEER)
        assertEquals("Engineer", t.label)
        assertEquals("Independent biomedical technician", t.desc)
        assertTrue(t.active)
    }

    @Test fun `supplier tile is inactive with coming-soon desc`() {
        val t = roleTileText(UserRole.SUPPLIER)
        assertEquals("Supplier", t.label)
        assertEquals("Coming soon", t.desc)
        assertFalse(t.active)
    }

    @Test fun `manufacturer tile is inactive with coming-soon desc`() {
        val t = roleTileText(UserRole.MANUFACTURER)
        assertEquals("Manufacturer", t.label)
        assertEquals("Coming soon", t.desc)
        assertFalse(t.active)
    }

    @Test fun `logistics tile is inactive with coming-soon desc`() {
        val t = roleTileText(UserRole.LOGISTICS)
        assertEquals("Logistics", t.label)
        assertEquals("Coming soon", t.desc)
        assertFalse(t.active)
    }

    @Test fun `exactly two roles are active in v1`() {
        // Pins the v1 onboarding scope. When SUPPLIER /
        // MANUFACTURER / LOGISTICS finally ship, this count flips
        // — that's a deliberate change and should fail this test
        // so the reviewer notices the launch.
        val activeCount = UserRole.entries.count { roleTileText(it).active }
        assertEquals(2, activeCount)
    }

    @Test fun `every role has non-blank label and desc`() {
        // Defensive against a future role added to UserRole that
        // forgets a tile-text branch. when() is exhaustive on enums
        // so a missing branch is a compile error — but a stray
        // empty string would still pass compilation. Catch that.
        UserRole.entries.forEach { role ->
            val t = roleTileText(role)
            assertTrue("label blank for $role", t.label.isNotBlank())
            assertTrue("desc blank for $role", t.desc.isNotBlank())
        }
    }

    @Test fun `inactive roles all share the coming-soon copy`() {
        // The picker leans on identical "Coming soon" desc to
        // visually group the inactive tiles. If one branch drifts
        // (e.g. "Launching Q3") it'd break that visual grouping.
        UserRole.entries
            .filterNot { roleTileText(it).active }
            .forEach { role ->
                assertEquals(
                    "$role should use shared coming-soon desc",
                    "Coming soon",
                    roleTileText(role).desc,
                )
            }
    }
}
