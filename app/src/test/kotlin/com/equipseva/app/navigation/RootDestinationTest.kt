package com.equipseva.app.navigation

import com.equipseva.app.features.auth.SessionOwner
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/** Tests the production destination policy; Compose lifetime tests live separately. */
class RootDestinationTest {
    private val owner = SessionOwner("A", 1)
    private fun presented(state: SessionState) = SessionPresentation(state, owner)

    @Test fun `signed out is auth and initial unresolved state is pending`() {
        assertEquals(RootGate.AUTH, rootDestination(SessionPresentation(SessionState.SignedOut)).gate)
        assertEquals(RootGate.PENDING, rootDestination(SessionPresentation()).gate)
        assertEquals(RootGate.PENDING, rootDestination(SessionPresentation(owner = owner)).gate)
    }

    @Test fun `needs role always selects role gate`() {
        assertEquals(RootDestination(RootGate.ROLE, "A:1"), rootDestination(presented(SessionState.NeedsRole("A", null))))
    }

    @Test fun `supported ready and onboarding states preserve explicit role`() {
        listOf(UserRole.HOSPITAL, UserRole.ENGINEER).forEach { role ->
            assertEquals(RootDestination(RootGate.MAIN, "A:1", role),
                rootDestination(presented(SessionState.Ready("A", null, role.storageKey))))
            assertEquals(RootDestination(RootGate.ONBOARDING, "A:1", role),
                rootDestination(presented(SessionState.NeedsOnboarding("A", null, role.storageKey))))
        }
    }

    @Test fun `unknown admin blank and deferred roles cannot acquire supported surfaces`() {
        listOf("", " ", "admin", "founder", "unknown", "hospital", "ENGINEER",
            UserRole.SUPPLIER.storageKey, UserRole.MANUFACTURER.storageKey, UserRole.LOGISTICS.storageKey,
        ).forEach { role ->
            listOf(SessionState.Ready("A", null, role), SessionState.NeedsOnboarding("A", null, role)).forEach { state ->
                assertEquals("role=$role state=$state", RootDestination(RootGate.ROLE, "A:1"), rootDestination(presented(state)))
            }
        }
    }

    @Test fun `missing blank or mismatched owner never authorizes an authenticated gate`() {
        val states = listOf(SessionState.NeedsRole("A", null),
            SessionState.Ready("A", null, "engineer"), SessionState.NeedsOnboarding("A", null, "hospital_admin"))
        states.forEach { state ->
            listOf(null, SessionOwner("", 1), SessionOwner("B", 1)).forEach { invalidOwner ->
                assertEquals(RootGate.PENDING, rootDestination(SessionPresentation(state, invalidOwner)).gate)
            }
        }
    }

    @Test fun `transient unknown retains only a matching owned gate`() {
        val retained = SessionState.Ready("A", null, "engineer")
        assertEquals(rootDestination(presented(retained)), rootDestination(SessionPresentation(
            owner = owner, retainedState = retained, resolvingAuth = true)))
        assertEquals(RootGate.PENDING, rootDestination(SessionPresentation(
            owner = owner, retainedState = retained, resolvingAuth = false)).gate)
        assertEquals(RootGate.PENDING, rootDestination(SessionPresentation(
            owner = owner, retainedState = retained.copy(userId = "B"), resolvingAuth = true)).gate)
        assertEquals(RootGate.PENDING, rootDestination(SessionPresentation(owner = owner, resolvingAuth = true)).gate)
    }

    @Test fun `new same user generation and new role select distinct destinations`() {
        val first = presented(SessionState.Ready("A", null, "engineer"))
        assertNotEquals(rootDestination(first), rootDestination(first.copy(owner = SessionOwner("A", 2))))
        assertNotEquals(rootDestination(first), rootDestination(first.copy(state = SessionState.Ready("A", null, "hospital_admin"))))
        assertEquals(rootDestination(first), rootDestination(first.copy(state = SessionState.Ready("A", "updated@test.invalid", "engineer"))))
    }

    @Test fun `retained state cannot override an explicit current gate`() {
        val current = presented(SessionState.NeedsRole("A", null)).copy(
            retainedState = SessionState.Ready("A", null, "engineer"), resolvingAuth = true)
        assertEquals(RootGate.ROLE, rootDestination(current).gate)
    }
}
