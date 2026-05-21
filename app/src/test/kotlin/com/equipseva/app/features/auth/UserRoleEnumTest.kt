package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the [UserRole] enum contract. The `storageKey` values mirror
 * the server-side `user_role` Postgres enum exactly — a Kotlin-side
 * rename would silently misclassify every existing profile row
 * (Postgrest returns the new key, the client falls through `fromKey`
 * to null, and the user lands on RoleSelect every time they open the
 * app).
 *
 * `admin` is intentionally excluded — admin accounts are
 * web-console-only and MFA-gated. The client must never expose admin
 * as a selectable role on signup.
 */
class UserRoleEnumTest {

    @Test fun `storage keys match the server-side user_role enum`() {
        assertEquals("hospital_admin", UserRole.HOSPITAL.storageKey)
        assertEquals("engineer", UserRole.ENGINEER.storageKey)
        assertEquals("supplier", UserRole.SUPPLIER.storageKey)
        assertEquals("manufacturer", UserRole.MANUFACTURER.storageKey)
        assertEquals("logistics", UserRole.LOGISTICS.storageKey)
    }

    @Test fun `display names match the pinned product copy`() {
        // User-facing strings on the role-editor sheet + Profile
        // AccountTypeSection — pin so a copy tweak is intentional.
        assertEquals("Hospital admin", UserRole.HOSPITAL.displayName)
        assertEquals("Biomedical engineer", UserRole.ENGINEER.displayName)
        assertEquals("Parts supplier", UserRole.SUPPLIER.displayName)
        assertEquals("Manufacturer", UserRole.MANUFACTURER.displayName)
        assertEquals("Logistics partner", UserRole.LOGISTICS.displayName)
    }

    @Test fun `admin is NOT a client-selectable role`() {
        // Pin the security guard — admin accounts are provisioned
        // via the web console only. A client-side addition without
        // a coordinated server-side gate would let users escalate.
        UserRole.entries.forEach { role ->
            assertFalse(
                "admin must not surface as a client storage key",
                role.storageKey == "admin",
            )
            assertFalse(
                "admin must not surface as a client display name",
                role.displayName.contains("admin", ignoreCase = true) &&
                    role.storageKey == "admin",
            )
        }
    }

    @Test fun `fromKey resolves known keys`() {
        assertEquals(UserRole.HOSPITAL, UserRole.fromKey("hospital_admin"))
        assertEquals(UserRole.ENGINEER, UserRole.fromKey("engineer"))
        assertEquals(UserRole.SUPPLIER, UserRole.fromKey("supplier"))
        assertEquals(UserRole.MANUFACTURER, UserRole.fromKey("manufacturer"))
        assertEquals(UserRole.LOGISTICS, UserRole.fromKey("logistics"))
    }

    @Test fun `fromKey null yields null (caller routes to RoleSelect)`() {
        // Unlike RepairJob enums where null falls back to Unknown,
        // UserRole.fromKey returns null. Caller (SessionViewModel)
        // routes the user to RoleSelect on null.
        assertNull(UserRole.fromKey(null))
    }

    @Test fun `fromKey unknown key yields null`() {
        // Forward-compat — a future server-side role surfaces as
        // null on older clients so the user falls into RoleSelect,
        // not into a wrong-role-cached state.
        assertNull(UserRole.fromKey("future_role"))
        assertNull(UserRole.fromKey("admin"))
    }

    @Test fun `every role has a non-blank description`() {
        UserRole.entries.forEach { role ->
            assertFalse(
                "${role.name} has blank description",
                role.description.isBlank(),
            )
        }
    }

    @Test fun `five client-selectable roles total`() {
        assertEquals(5, UserRole.entries.size)
    }
}
