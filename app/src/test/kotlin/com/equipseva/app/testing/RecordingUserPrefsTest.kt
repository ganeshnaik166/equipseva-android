package com.equipseva.app.testing

import com.equipseva.app.testing.RecordingUserPrefs.WriteEvent
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RecordingUserPrefsTest {
    @Test fun `before hook pauses without recording or publishing role`() = runTest {
        val prefs = RecordingUserPrefs.create()
        val release = CompletableDeferred<Unit>()
        prefs.beforeActiveRoleWrite = { release.await() }
        val write = async { prefs.mock.setActiveRole("hospital") }
        runCurrent()
        assertFalse(write.isCompleted)
        assertNull(prefs.activeRole.value)
        assertTrue(prefs.writeEvents.isEmpty())
        release.complete(Unit)
        write.await()
        assertEquals("hospital", prefs.activeRole.value)
        assertEquals(listOf(WriteEvent.ActiveRoleSet("hospital")), prefs.writeEvents)
    }

    @Test fun `after hook exposes published role before caller writes onboarding`() = runTest {
        val prefs = RecordingUserPrefs.create()
        val release = CompletableDeferred<Unit>()
        prefs.afterActiveRolePublication = { release.await() }
        val write = async {
            prefs.mock.setActiveRole("hospital")
            prefs.mock.setV2OnboardingComplete(true)
        }
        runCurrent()
        assertFalse(write.isCompleted)
        assertEquals("hospital", prefs.activeRole.value)
        assertFalse(prefs.v2OnboardingComplete.value)
        assertEquals(listOf(WriteEvent.ActiveRoleSet("hospital")), prefs.writeEvents)
        release.complete(Unit)
        write.await()
        assertTrue(prefs.v2OnboardingComplete.value)
        assertEquals(
            listOf(WriteEvent.ActiveRoleSet("hospital"), WriteEvent.V2OnboardingSet(true)),
            prefs.writeEvents,
        )
    }

    @Test fun `ledger preserves cross setter order including clears and repeated calls`() = runTest {
        val prefs = RecordingUserPrefs.create(initialTourSeen = false)
        prefs.mock.setV2OnboardingComplete(true)
        prefs.mock.setActiveRole("hospital")
        prefs.mock.setLastScreen("bookings")
        prefs.mock.setTourSeen()
        prefs.mock.setTourSeen()
        prefs.mock.clearActiveRole()
        prefs.mock.setLastScreen(null)
        prefs.mock.setV2OnboardingComplete(false)
        assertEquals(
            listOf(
                WriteEvent.V2OnboardingSet(true), WriteEvent.ActiveRoleSet("hospital"),
                WriteEvent.LastScreenSet("bookings"), WriteEvent.TourSeenSet,
                WriteEvent.TourSeenSet, WriteEvent.ActiveRoleCleared,
                WriteEvent.LastScreenSet(null), WriteEvent.V2OnboardingSet(false),
            ),
            prefs.writeEvents,
        )
        assertEquals(listOf("hospital", null), prefs.activeRoleWrites)
        assertEquals(listOf(true, false), prefs.v2OnboardingWrites)
        assertEquals(listOf("bookings", null), prefs.lastScreenWrites)
        assertEquals(2, prefs.tourSeenWrites)
        assertNull(prefs.activeRole.value)
        assertNull(prefs.lastScreen.value)
        assertFalse(prefs.v2OnboardingComplete.value)
        assertTrue(prefs.tourSeen.value)
    }

    @Test fun `last screen clears blank values but preserves nonblank route and raw arguments`() = runTest {
        val prefs = RecordingUserPrefs.create()
        val inputs = listOf("", " \t\n", null)
        for (route in inputs) {
            prefs.mock.setLastScreen(" bookings ")
            assertEquals(" bookings ", prefs.lastScreen.value)
            prefs.mock.setLastScreen(route)
            assertNull(prefs.lastScreen.value)
        }
        val rawWrites = inputs.flatMap { listOf(" bookings ", it) }
        assertEquals(rawWrites, prefs.lastScreenWrites)
        assertEquals(rawWrites.map { WriteEvent.LastScreenSet(it) }, prefs.writeEvents)
    }
}
