package com.equipseva.app.core.data.prefs

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Robolectric proof-of-concept: a test that needs a real Android
 * [Context] (here for the DataStore-backed theme pref) runs on the JVM
 * without an emulator.
 *
 * Most tests in this module should stay pure-JUnit — Robolectric is
 * 100-1000x slower per test. Use it only when the surface under test
 * genuinely needs a [Context] (DataStore, NotificationManager,
 * PackageManager) and the alternative would be heavy mocking.
 *
 * Pattern documented for follow-up tests:
 *   - @RunWith(RobolectricTestRunner::class)
 *   - @Config(application = ..., manifest = Config.NONE)
 *   - Pull the Context via ApplicationProvider.getApplicationContext().
 *   - Drive coroutines via kotlinx.coroutines.test.runTest.
 *
 * The Hilt graph is NOT booted here — that's phase-2 wiring. This
 * test only validates the simpler DataStore-with-real-Context path.
 */
@RunWith(RobolectricTestRunner::class)
@Config(
    // Force a vanilla android.app.Application so Robolectric doesn't
    // boot the real EquipSevaApplication (which fires up the Hilt
    // graph + a real SupabaseClient → SettingsSessionManager that
    // can't initialise outside an emulator). Hilt-aware tests live
    // separately and use HiltTestApplication via @HiltAndroidTest.
    application = android.app.Application::class,
    manifest = Config.NONE,
)
class UserPrefsThemeRobolectricTest {

    // Use a uniquely-named DataStore so this test doesn't collide with
    // the prod "equipseva_prefs" file Robolectric materializes in the
    // module's working dir.
    private val Context.testThemeStore by preferencesDataStore(name = "userprefs_theme_robolectric_test")

    private val THEME_KEY = stringPreferencesKey("theme")

    private val context: Context = ApplicationProvider.getApplicationContext()

    @After fun clearStore() = runTest {
        // DataStore writes survive across tests in the same JVM. Reset.
        context.testThemeStore.edit { it.clear() }
    }

    @Test fun `theme key round-trips through DataStore and resolves via ThemeMode_fromKey`() = runTest {
        // Write the dark-mode key, read it back, fold through ThemeMode.
        context.testThemeStore.edit { it[THEME_KEY] = ThemeMode.Dark.storageKey }
        val resolved = context.testThemeStore.data
            .map { ThemeMode.fromKey(it[THEME_KEY]) }
            .first()
        assertEquals(ThemeMode.Dark, resolved)
    }

    @Test fun `absent key folds to ThemeMode_Light per fromKey contract`() = runTest {
        val resolved = context.testThemeStore.data
            .map { ThemeMode.fromKey(it[THEME_KEY]) }
            .first()
        assertEquals(ThemeMode.Light, resolved)
    }

    @Test fun `unknown stored value folds to ThemeMode_Light per fromKey fallback`() = runTest {
        context.testThemeStore.edit { it[THEME_KEY] = "auto" }
        val resolved = context.testThemeStore.data
            .map { ThemeMode.fromKey(it[THEME_KEY]) }
            .first()
        assertEquals(ThemeMode.Light, resolved)
    }
}
