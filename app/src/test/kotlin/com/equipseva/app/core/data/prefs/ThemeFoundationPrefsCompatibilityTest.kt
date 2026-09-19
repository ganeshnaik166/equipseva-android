package com.equipseva.app.core.data.prefs

import android.app.Application
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class])
class ThemeFoundationPrefsCompatibilityTest {
    @Test fun `production preferences retain stored theme across wrapper recreation and preserve other keys`() = runBlocking {
        withTimeout(10_000) {
            val app = ApplicationProvider.getApplicationContext<Application>()
            IsolatedUiPackageParser.assertIsolated(app)
            val secure = mockk<SecurePrefs>(relaxed = true)
            // Seed legacy data through the exact production store. Do not introduce a parallel test store.
            val getter = Class.forName("com.equipseva.app.core.data.prefs.UserPrefsKt")
                .getDeclaredMethod("getPrefsStore", Context::class.java).apply { isAccessible = true }
            @Suppress("UNCHECKED_CAST")
            val store = getter.invoke(null, app) as DataStore<Preferences>
            val themeKey = stringPreferencesKey("theme")
            val screenKey = stringPreferencesKey("last_screen")
            val original = store.data.first()
            try {
                store.edit { it.remove(themeKey); it[screenKey] = "synthetic-screen" }
                assertEquals(ThemeMode.Light, UserPrefs(app, secure).themeMode.first())
                store.edit { it[themeKey] = "unknown-old-choice" }
                assertEquals(ThemeMode.Light, UserPrefs(app, secure).themeMode.first())
                listOf(ThemeMode.Dark, ThemeMode.Light, ThemeMode.System).forEach { choice ->
                    val prefs = UserPrefs(app, secure)
                    prefs.setThemeMode(choice)
                    val recreated = UserPrefs(app, secure)
                    assertEquals(choice, recreated.themeMode.first())
                    assertEquals(choice.storageKey, recreated.theme.first())
                    assertEquals("synthetic-screen", recreated.lastScreen.first())
                }
            } finally {
                store.edit { it.clear(); it += original }
            }
        }
    }
}
