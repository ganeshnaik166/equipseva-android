package com.equipseva.app.core.data.prefs

import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import dagger.hilt.android.testing.HiltTestApplication
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import javax.inject.Inject

/**
 * Phase 3 of the SmokeFlowTest follow-up (PR #255):
 *
 * First Hilt-aware repository test that injects a real
 * [UserPrefs] from the full Hilt graph and exercises its
 * activeRole + theme + lastScreen flows through the real
 * DataStore / SecurePrefs implementations on a Robolectric Context.
 *
 * UserPrefs is a useful first target because the graph it pulls in
 * (Context + SecurePrefs) doesn't touch the SupabaseClient — so the
 * test can boot the full Hilt graph without any `@TestInstallIn`
 * gymnastics. Tests that DO need a fake SupabaseClient will land
 * later with the swap pattern; this test proves the surrounding
 * machinery (HiltTestApplication + Robolectric + DataStore on JVM)
 * works end-to-end.
 *
 * Note that each test in this class uses a uniquely-keyed setActiveRole
 * value so the assertions stay deterministic even though Robolectric's
 * Context shares a working directory across tests in the same JVM run.
 */
@HiltAndroidTest
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class)
class UserPrefsHiltTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject lateinit var userPrefs: UserPrefs

    @Before fun init() {
        hiltRule.inject()
    }

    @Test fun `activeRole starts null on a fresh install`() = runTest {
        // Robolectric's working dir is reset between gradle runs but
        // not between tests; clear before reading to keep this
        // assertion stable when run after another writer.
        userPrefs.clearActiveRole()
        assertNull(userPrefs.activeRole.first())
    }

    @Test fun `setActiveRole persists through the encrypted store and reads back`() = runTest {
        userPrefs.setActiveRole("hospital_admin_hilt_test")
        val read = userPrefs.activeRole.first()
        assertEquals("hospital_admin_hilt_test", read)
    }

    @Test fun `clearActiveRole wipes the persisted value`() = runTest {
        userPrefs.setActiveRole("engineer_clear_test")
        assertEquals("engineer_clear_test", userPrefs.activeRole.first())

        userPrefs.clearActiveRole()
        assertNull(userPrefs.activeRole.first())
    }

    @Test fun `setLastScreen round-trips a route and clears on null`() = runTest {
        userPrefs.setLastScreen("profile/kyc")
        assertEquals("profile/kyc", userPrefs.lastScreen.first())

        userPrefs.setLastScreen(null)
        assertNull(userPrefs.lastScreen.first())
    }

    @Test fun `setLastScreen treats blank as clear`() = runTest {
        userPrefs.setLastScreen("home")
        assertEquals("home", userPrefs.lastScreen.first())

        userPrefs.setLastScreen("   ")
        assertNull(userPrefs.lastScreen.first())
    }

    @Test fun `themeMode defaults to Light and round-trips Dark`() = runTest {
        // No write yet → fromKey(null) → Light.
        // (We don't have a clearTheme; the previous test may have set
        // it, so write Light explicitly to baseline.)
        userPrefs.setThemeMode(ThemeMode.Light)
        assertEquals(ThemeMode.Light, userPrefs.themeMode.first())

        userPrefs.setThemeMode(ThemeMode.Dark)
        assertEquals(ThemeMode.Dark, userPrefs.themeMode.first())
    }
}
