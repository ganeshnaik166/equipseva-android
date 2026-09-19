package com.equipseva.app.testing

import com.equipseva.app.core.data.prefs.UserPrefs
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Test double for [UserPrefs] built on MockK (the class is final and its
 * storage is a process-wide `preferencesDataStore` delegate, so a real
 * instance cannot be given a per-test file — see the JVM-wide singleton
 * note in RequestServiceDraftIdentityIntegrationTest).
 *
 * Every flow the auth / navigation ViewModels read is a [MutableStateFlow]
 * the test can drive, and every write those ViewModels perform is recorded
 * in order so a test can assert *what* was written and *when* — including
 * a write that lands for the wrong account after a switch.
 *
 * [beforeActiveRoleWrite] pauses `setActiveRole` before recording or publication.
 * [afterActiveRolePublication] pauses it after the role flow is updated but
 * before the setter returns. Production publishes through SecurePrefs before
 * its suspending DataStore edit; the latter hook characterises the observable
 * role-with-old-onboarding state (A9). Neither hook simulates persistence.
 * Drive this double on a single coroutine test scheduler; it is not a
 * thread-safe substitute for the production stores.
 */
class RecordingUserPrefs private constructor(val mock: UserPrefs) {

    sealed interface WriteEvent {
        data class ActiveRoleSet(val role: String) : WriteEvent
        data object ActiveRoleCleared : WriteEvent
        data class V2OnboardingSet(val complete: Boolean) : WriteEvent
        /** Raw caller argument; the published flow normalises blank to null. */
        data class LastScreenSet(val route: String?) : WriteEvent
        data object TourSeenSet : WriteEvent
    }

    /** Applied writes across all supported setters, recorded before publication. */
    val writeEvents = mutableListOf<WriteEvent>()

    val activeRole = MutableStateFlow<String?>(null)
    val v2OnboardingComplete = MutableStateFlow(false)
    val tourSeen = MutableStateFlow(true)
    val lastScreen = MutableStateFlow<String?>(null)

    /** Every role write in order; `null` records a `clearActiveRole()` call. */
    val activeRoleWrites = mutableListOf<String?>()
    val v2OnboardingWrites = mutableListOf<Boolean>()
    val lastScreenWrites = mutableListOf<String?>()
    var tourSeenWrites = 0
        private set

    var beforeActiveRoleWrite: suspend () -> Unit = {}
    var afterActiveRolePublication: suspend () -> Unit = {}

    companion object {
        fun create(
            initialActiveRole: String? = null,
            initialV2OnboardingComplete: Boolean = false,
            initialTourSeen: Boolean = true,
        ): RecordingUserPrefs {
            val prefs = RecordingUserPrefs(mockk(relaxed = false))
            prefs.activeRole.value = initialActiveRole
            prefs.v2OnboardingComplete.value = initialV2OnboardingComplete
            prefs.tourSeen.value = initialTourSeen
            with(prefs) {
                every { mock.activeRole } returns activeRole
                every { mock.v2OnboardingComplete } returns v2OnboardingComplete
                every { mock.lastScreen } returns lastScreen
                every { mock.observeTourSeen() } returns tourSeen
                coEvery { mock.setActiveRole(any()) } coAnswers {
                    val role = firstArg<String>()
                    beforeActiveRoleWrite()
                    writeEvents += WriteEvent.ActiveRoleSet(role)
                    activeRoleWrites += role
                    activeRole.value = role
                    afterActiveRolePublication()
                }
                coEvery { mock.clearActiveRole() } coAnswers {
                    writeEvents += WriteEvent.ActiveRoleCleared
                    activeRoleWrites += null
                    activeRole.value = null
                }
                coEvery { mock.setV2OnboardingComplete(any()) } coAnswers {
                    val complete = firstArg<Boolean>()
                    writeEvents += WriteEvent.V2OnboardingSet(complete)
                    v2OnboardingWrites += complete
                    v2OnboardingComplete.value = complete
                }
                coEvery { mock.setLastScreen(any()) } coAnswers {
                    val route = firstArg<String?>()
                    writeEvents += WriteEvent.LastScreenSet(route)
                    lastScreenWrites += route
                    lastScreen.value = route?.takeUnless { it.isBlank() }
                }
                coEvery { mock.setTourSeen() } coAnswers {
                    writeEvents += WriteEvent.TourSeenSet
                    tourSeenWrites++
                    tourSeen.value = true
                }
            }
            return prefs
        }
    }
}
