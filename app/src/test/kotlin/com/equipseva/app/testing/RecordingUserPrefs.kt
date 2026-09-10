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
 * [beforeActiveRoleWrite] is a suspension hook run inside `setActiveRole`
 * before the value is applied. Production `UserPrefs.setActiveRole` suspends
 * on a DataStore edit, so a ViewModel that writes the role and then sets a
 * second flag has an observable intermediate state; the hook lets a test
 * park the write exactly there.
 */
class RecordingUserPrefs private constructor(val mock: UserPrefs) {

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
                    activeRoleWrites += role
                    activeRole.value = role
                }
                coEvery { mock.clearActiveRole() } coAnswers {
                    activeRoleWrites += null
                    activeRole.value = null
                }
                coEvery { mock.setV2OnboardingComplete(any()) } coAnswers {
                    val complete = firstArg<Boolean>()
                    v2OnboardingWrites += complete
                    v2OnboardingComplete.value = complete
                }
                coEvery { mock.setLastScreen(any()) } coAnswers {
                    val route = firstArg<String?>()
                    lastScreenWrites += route
                    lastScreen.value = route
                }
                coEvery { mock.setTourSeen() } coAnswers {
                    tourSeenWrites++
                    tourSeen.value = true
                }
            }
            return prefs
        }
    }
}
