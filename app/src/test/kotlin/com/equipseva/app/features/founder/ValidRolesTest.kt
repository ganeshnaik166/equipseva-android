package com.equipseva.app.features.founder

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the founder admin's role-change dropdown options. This is a
 * security-sensitive list — the dropdown lets the founder
 * force-change another user's role; without the explicit allowlist
 * a bug in the UI dropdown population could let the founder promote
 * a user to `admin` (which is supposed to be web-console-only with
 * MFA mandatory).
 *
 * Pinned to mirror [UserRole] entries exactly — adding a new role to
 * UserRole MUST come with adding it here too, and vice versa.
 */
class ValidRolesTest {

    @Test fun `VALID_ROLES has exactly five entries matching UserRole entries`() {
        assertEquals(5, VALID_ROLES.size)
        assertEquals(UserRole.entries.size, VALID_ROLES.size)
    }

    @Test fun `VALID_ROLES contains every UserRole storageKey`() {
        UserRole.entries.forEach { role ->
            assertTrue(
                "${role.name} storageKey missing from founder VALID_ROLES",
                VALID_ROLES.contains(role.storageKey),
            )
        }
    }

    @Test fun `VALID_ROLES does NOT contain admin`() {
        // Critical security guard — admin promotion happens via the
        // web console only, with MFA gating. The founder mobile tool
        // must never expose admin as a settable role.
        assertFalse(
            "admin must not be settable from the founder mobile tool",
            VALID_ROLES.contains("admin"),
        )
    }

    @Test fun `VALID_ROLES does NOT contain superadmin or other escalated roles`() {
        // Forward-compat defensive — any role that grants RPC-level
        // privileges (admin, founder-as-stored-role, system) must be
        // absent so a refactor that drops the explicit allowlist
        // surfaces.
        listOf("admin", "founder", "system", "service", "root").forEach { role ->
            assertFalse(
                "$role must not be in VALID_ROLES",
                VALID_ROLES.contains(role),
            )
        }
    }

    @Test fun `entries are all lowercase ascii (server-side enum format)`() {
        VALID_ROLES.forEach { key ->
            assertEquals("$key should be lowercase", key, key.lowercase())
            assertTrue("$key contains whitespace", key.none { it.isWhitespace() })
        }
    }
}
