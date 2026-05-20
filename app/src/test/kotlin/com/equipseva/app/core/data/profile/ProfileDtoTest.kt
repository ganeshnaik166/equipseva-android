package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Profile is read off the home screen, the role-aware bottom nav, the buyer-KYC
 * gate, the founder-dashboard chip, and every screen that has to call
 * `profile.displayName`. A single null-handling bug in the mapper propagates
 * everywhere. Pin the contract.
 */
class ProfileDtoTest {

    @Test fun `single-role dto maps role and leaves multi-role lists empty`() {
        val dto = ProfileDto(
            id = "u1",
            email = "ganesh@example.com",
            fullName = "Ganesh",
            role = "hospital_admin",
        )

        val domain = dto.toDomain()
        assertEquals(UserRole.HOSPITAL, domain.role)
        assertEquals("hospital_admin", domain.rawRoleKey)
        assertTrue(domain.roles.isEmpty())
        assertNull(domain.activeRole)
        assertNull(domain.activeRoleKey)
    }

    @Test fun `unknown role key leaves enum null but keeps raw key for fallback`() {
        // The hub layer falls back to rawRoleKey when role is unmapped so a
        // newly-added server enum doesn't lock the user out of the app.
        val dto = ProfileDto(
            id = "u2",
            role = "nurse_admin",
        )
        val domain = dto.toDomain()
        assertNull(domain.role)
        assertEquals("nurse_admin", domain.rawRoleKey)
    }

    @Test fun `multi-role array maps every recognized role and skips unknowns`() {
        val dto = ProfileDto(
            id = "u3",
            roles = listOf("hospital_admin", "supplier", "nurse_admin"),
            activeRoleKey = "supplier",
        )
        val domain = dto.toDomain()
        assertEquals(listOf(UserRole.HOSPITAL, UserRole.SUPPLIER), domain.roles)
        assertEquals(listOf("hospital_admin", "supplier", "nurse_admin"), domain.rawRoleKeys)
        assertEquals(UserRole.SUPPLIER, domain.activeRole)
        assertEquals("supplier", domain.activeRoleKey)
    }

    @Test fun `null buyer kyc status defaults to unsubmitted`() {
        // The KYC gate branches on this string; null would crash the
        // ordinarily-pessimistic check.
        val dto = ProfileDto(id = "u4")
        assertEquals("unsubmitted", dto.toDomain().buyerKycStatus)
    }

    @Test fun `organization summary flattens onto domain fields`() {
        val dto = ProfileDto(
            id = "u5",
            organizationId = "org-1",
            organizations = OrganizationSummaryDto(
                name = "Apollo BLR",
                city = "Bangalore",
                state = "KA",
            ),
        )
        val domain = dto.toDomain()
        assertEquals("Apollo BLR", domain.organizationName)
        assertEquals("Bangalore", domain.organizationCity)
        assertEquals("KA", domain.organizationState)
    }

    @Test fun `displayName prefers full_name, falls back to email local-part, then User`() {
        // Pin the three branches of Profile.displayName — used on the home
        // greeting + every chat bubble.
        assertEquals(
            "Ganesh",
            ProfileDto(id = "u6", fullName = "Ganesh", email = "x@y.com").toDomain().displayName,
        )
        assertEquals(
            "ravi",
            ProfileDto(id = "u7", fullName = "   ", email = "ravi@example.com").toDomain().displayName,
        )
        assertEquals(
            "User",
            ProfileDto(id = "u8").toDomain().displayName,
        )
    }

    @Test fun `locationLine joins city and state and collapses to null when blank`() {
        val both = ProfileDto(
            id = "u9",
            organizations = OrganizationSummaryDto(city = "Bangalore", state = "KA"),
        ).toDomain()
        assertEquals("Bangalore, KA", both.locationLine)

        val none = ProfileDto(id = "u10").toDomain()
        assertNull(none.locationLine)

        val cityOnly = ProfileDto(
            id = "u11",
            organizations = OrganizationSummaryDto(city = "Bangalore", state = "   "),
        ).toDomain()
        assertEquals("Bangalore", cityOnly.locationLine)
    }

    @Test fun `isFounder is case-insensitive and matches the pinned email`() {
        val founder = ProfileDto(id = "u12", email = "Ganesh1431.Dhanavath@Gmail.com").toDomain()
        assertTrue(founder.isFounder())

        val notFounder = ProfileDto(id = "u13", email = "someone-else@example.com").toDomain()
        assertFalse(notFounder.isFounder())

        val noEmail = ProfileDto(id = "u14").toDomain()
        assertFalse(noEmail.isFounder())
    }

    @Test fun `email and phone verification flags default to false`() {
        // KYC Step 1 checks these to render the "Verify" CTA — if missing,
        // a server-side trigger probably never fired and we should not
        // claim the column is verified.
        val dto = ProfileDto(id = "u15")
        val domain = dto.toDomain()
        assertFalse(domain.emailVerified)
        assertFalse(domain.phoneVerified)
    }

    @Test fun `role keys round-trip the UserRole enum exactly`() {
        // UserRole.HOSPITAL surfaces as "hospital_admin" — the server name
        // (not the display name). Drift here would silently kick everyone
        // back through onboarding because role_confirmed checks compare keys.
        assertEquals("hospital_admin", UserRole.HOSPITAL.storageKey)
        assertEquals("engineer", UserRole.ENGINEER.storageKey)
        assertEquals("supplier", UserRole.SUPPLIER.storageKey)
        assertEquals("manufacturer", UserRole.MANUFACTURER.storageKey)
        assertEquals("logistics", UserRole.LOGISTICS.storageKey)

        UserRole.entries.forEach { role ->
            assertEquals(role, UserRole.fromKey(role.storageKey))
        }
        assertNull(UserRole.fromKey("admin"))
        assertNull(UserRole.fromKey(null))
    }
}
