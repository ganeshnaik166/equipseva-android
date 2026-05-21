package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the [ProfileDto] → [Profile] mapper. The mapper is the only
 * place wire-level role keys are turned into [UserRole] entries and
 * the embedded `organizations(...)` is flattened to three top-level
 * fields. A regression here would surface as a missing org name on the
 * Profile screen or a null `role` after sign-in (cascading into the
 * post-login route resolution).
 */
class ProfileDtoMapperTest {

    private fun emptyDto(id: String = "p1") = ProfileDto(id = id)

    @Test fun `minimal dto maps to defaults`() {
        val profile = emptyDto().toDomain()

        assertEquals("p1", profile.id)
        assertNull(profile.email)
        assertNull(profile.phone)
        assertNull(profile.fullName)
        assertNull(profile.avatarUrl)
        assertNull(profile.role)
        assertNull(profile.rawRoleKey)
        assertFalse(profile.roleConfirmed)
        assertFalse(profile.onboardingCompleted)
        assertTrue(profile.isActive)
        assertNull(profile.organizationId)
        assertNull(profile.organizationName)
        assertNull(profile.organizationCity)
        assertNull(profile.organizationState)
        assertTrue(profile.roles.isEmpty())
        assertTrue(profile.rawRoleKeys.isEmpty())
        assertNull(profile.activeRole)
        assertNull(profile.activeRoleKey)
        // buyer_kyc_status column is wire-nullable but the domain
        // always has a default; this guarantees the gate computation
        // (KYC step) gets a string, never an NPE.
        assertEquals("unsubmitted", profile.buyerKycStatus)
        assertFalse(profile.emailVerified)
        assertFalse(profile.phoneVerified)
    }

    @Test fun `known single role storage key maps to enum + retains raw key`() {
        val profile = emptyDto().copy(role = "hospital_admin").toDomain()
        assertEquals(UserRole.HOSPITAL, profile.role)
        assertEquals("hospital_admin", profile.rawRoleKey)
    }

    @Test fun `unknown role storage key keeps raw and yields null typed role`() {
        // Forward-compat: a new server-side role surfaces as `rawRoleKey`
        // so debug surfaces / founder dashboard can still display the
        // string, while `role` stays null so downstream when()s default.
        val profile = emptyDto().copy(role = "future_role").toDomain()
        assertNull(profile.role)
        assertEquals("future_role", profile.rawRoleKey)
    }

    @Test fun `roles array maps known keys and drops unknown ones`() {
        // mapNotNull is intentional — we don't want a single typo to
        // nuke the whole multi-role badge row.
        val profile = emptyDto().copy(
            roles = listOf("hospital_admin", "engineer", "future_role"),
        ).toDomain()

        assertEquals(
            listOf(UserRole.HOSPITAL, UserRole.ENGINEER),
            profile.roles,
        )
        // rawRoleKeys preserves the wire payload verbatim so the
        // /founder/diagnostics tab can show drift.
        assertEquals(
            listOf("hospital_admin", "engineer", "future_role"),
            profile.rawRoleKeys,
        )
    }

    @Test fun `active role key maps to enum`() {
        val profile = emptyDto().copy(activeRoleKey = "supplier").toDomain()
        assertEquals(UserRole.SUPPLIER, profile.activeRole)
        assertEquals("supplier", profile.activeRoleKey)
    }

    @Test fun `unknown active role storage key yields null active role`() {
        val profile = emptyDto().copy(activeRoleKey = "wat").toDomain()
        assertNull(profile.activeRole)
        assertEquals("wat", profile.activeRoleKey)
    }

    @Test fun `embedded organization fields flatten to top-level domain fields`() {
        val profile = emptyDto().copy(
            organizationId = "org1",
            organizations = OrganizationSummaryDto(
                name = "Apollo Hospitals",
                city = "Chennai",
                state = "TN",
            ),
        ).toDomain()

        assertEquals("org1", profile.organizationId)
        assertEquals("Apollo Hospitals", profile.organizationName)
        assertEquals("Chennai", profile.organizationCity)
        assertEquals("TN", profile.organizationState)
    }

    @Test fun `null organizations object leaves org fields null`() {
        // organization_id alone (without the embed) is the legacy shape
        // — UI gracefully degrades to "no org" when the join didn't run.
        val profile = emptyDto().copy(organizationId = "org1", organizations = null).toDomain()

        assertEquals("org1", profile.organizationId)
        assertNull(profile.organizationName)
        assertNull(profile.organizationCity)
        assertNull(profile.organizationState)
    }

    @Test fun `verification flags pass through verbatim`() {
        val profile = emptyDto().copy(emailVerified = true, phoneVerified = true).toDomain()
        assertTrue(profile.emailVerified)
        assertTrue(profile.phoneVerified)
    }

    @Test fun `buyer kyc status passes through when non-null`() {
        val profile = emptyDto().copy(buyerKycStatus = "verified").toDomain()
        assertEquals("verified", profile.buyerKycStatus)
    }

    @Test fun `displayName prefers fullName when non-blank`() {
        val profile = emptyDto().copy(
            fullName = "Ravi Kumar",
            email = "ravi.k@hospital.in",
        ).toDomain()
        assertEquals("Ravi Kumar", profile.displayName)
    }

    @Test fun `displayName falls back to email-local-part when fullName is blank`() {
        val profile = emptyDto().copy(
            fullName = "   ",
            email = "ravi.k@hospital.in",
        ).toDomain()
        assertEquals("ravi.k", profile.displayName)
    }

    @Test fun `displayName ultimate fallback is the literal User`() {
        val profile = emptyDto().toDomain()
        assertEquals("User", profile.displayName)
    }

    @Test fun `locationLine joins city + state with comma`() {
        val profile = emptyDto().copy(
            organizations = OrganizationSummaryDto(name = "N/A", city = "Bengaluru", state = "KA"),
        ).toDomain()
        assertEquals("Bengaluru, KA", profile.locationLine)
    }

    @Test fun `locationLine drops blank components`() {
        val profile = emptyDto().copy(
            organizations = OrganizationSummaryDto(name = "N/A", city = "Bengaluru", state = "  "),
        ).toDomain()
        assertEquals("Bengaluru", profile.locationLine)
    }

    @Test fun `locationLine is null when both city + state are blank`() {
        val profile = emptyDto().copy(
            organizations = OrganizationSummaryDto(name = "N/A", city = " ", state = null),
        ).toDomain()
        assertNull(profile.locationLine)
    }

    @Test fun `isFounder matches the pinned founder email case-insensitively`() {
        val founder = emptyDto().copy(email = "GANESH1431.dhanavath@gmail.com").toDomain()
        assertTrue(founder.isFounder())

        val other = emptyDto().copy(email = "someone-else@gmail.com").toDomain()
        assertFalse(other.isFounder())
    }

    @Test fun `isFounder false when email is null`() {
        // Email-pinned founder check is purely client-side — a null
        // email must NOT promote a row to founder. Server still gates
        // privileged RPCs via `is_founder()`.
        val profile = emptyDto().toDomain()
        assertFalse(profile.isFounder())
    }
}
