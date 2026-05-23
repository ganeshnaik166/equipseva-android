package com.equipseva.app.features.profile

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IsV1ActiveRoleTest {

    @Test fun `HOSPITAL is v1 active`() {
        assertTrue(isV1ActiveRole(UserRole.HOSPITAL))
    }

    @Test fun `ENGINEER is v1 active`() {
        assertTrue(isV1ActiveRole(UserRole.ENGINEER))
    }

    @Test fun `SUPPLIER is v1 inactive (marketplace not shipped)`() {
        // Critical regression target — switching to SUPPLIER would
        // land the user on an empty hub.
        assertFalse(isV1ActiveRole(UserRole.SUPPLIER))
    }

    @Test fun `MANUFACTURER is v1 inactive`() {
        assertFalse(isV1ActiveRole(UserRole.MANUFACTURER))
    }

    @Test fun `LOGISTICS is v1 inactive`() {
        assertFalse(isV1ActiveRole(UserRole.LOGISTICS))
    }

    @Test fun `exactly two roles are v1 active`() {
        val activeCount = UserRole.entries.count { isV1ActiveRole(it) }
        // Pin the count — a refactor that flipped a marketplace role
        // to active without shipping the hub would change this.
        assertTrue(activeCount == 2)
    }
}
