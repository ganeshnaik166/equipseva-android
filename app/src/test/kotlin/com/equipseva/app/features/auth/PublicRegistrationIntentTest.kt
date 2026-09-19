package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** A saved registration choice is not a server role, membership or entitlement. */
class PublicRegistrationIntentTest {
    @Test fun `only the three public registration intentions exist`() {
        assertEquals(
            setOf(
                PublicRegistrationIntent.BIOMEDICAL_ENGINEER,
                PublicRegistrationIntent.HOSPITAL,
                PublicRegistrationIntent.ENGINEERING_ORGANISATION,
            ),
            PublicRegistrationIntent.entries.toSet(),
        )
    }

    @Test fun `saved keys remain distinct from legacy authorization role keys`() {
        assertEquals("biomedical_engineer", PublicRegistrationIntent.BIOMEDICAL_ENGINEER.savedKey)
        assertEquals("hospital", PublicRegistrationIntent.HOSPITAL.savedKey)
        assertEquals("engineering_organisation", PublicRegistrationIntent.ENGINEERING_ORGANISATION.savedKey)
        assertEquals(3, PublicRegistrationIntent.entries.map { it.savedKey }.toSet().size)
    }

    @Test fun `engineer intention restores from its exact saved key`() {
        assertEquals(
            PublicRegistrationIntent.BIOMEDICAL_ENGINEER,
            PublicRegistrationIntent.fromSavedKey("biomedical_engineer"),
        )
    }

    @Test fun `hospital intention restores from its exact saved key`() {
        assertEquals(
            PublicRegistrationIntent.HOSPITAL,
            PublicRegistrationIntent.fromSavedKey("hospital"),
        )
    }

    @Test fun `organisation intention restores from its exact saved key`() {
        assertEquals(
            PublicRegistrationIntent.ENGINEERING_ORGANISATION,
            PublicRegistrationIntent.fromSavedKey("engineering_organisation"),
        )
    }

    @Test fun `privileged and backend role values are not registration intentions`() {
        listOf(
            "admin", "founder", "owner", "platform_owner", "team_admin",
            "organisation_admin", "hospital_admin", "engineer",
            "supplier", "manufacturer", "logistics",
        ).forEach { key ->
            assertNull("must reject non-intention key: $key", PublicRegistrationIntent.fromSavedKey(key))
        }
    }

    @Test fun `missing blank and future choices remain unresolved`() {
        listOf(null, "", " ", "\n\t", "future_intention").forEach { key ->
            assertNull(PublicRegistrationIntent.fromSavedKey(key))
        }
    }

    @Test fun `case whitespace encoded and embedded variants are not normalized into a choice`() {
        listOf(
            "HOSPITAL", "Hospital", " hospital", "hospital ", "hospital\n",
            "biomedical_engineer\u0000", "engineering_organisation/admin",
            "%68ospital", "hospital?role=admin", "hospital\u200B",
            "engineering_organization", "x".repeat(1024),
        ).forEach { key ->
            assertNull("must reject malformed saved key", PublicRegistrationIntent.fromSavedKey(key))
        }
    }
}
