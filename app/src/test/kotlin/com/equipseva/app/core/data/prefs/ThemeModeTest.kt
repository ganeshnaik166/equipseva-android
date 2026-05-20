package com.equipseva.app.core.data.prefs

import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeModeTest {

    @Test fun `storage keys match what DataStore writes`() {
        // Pin the exact strings written into UserPrefs.Keys.THEME — drift
        // would silently force everyone to the Light fallback after upgrade
        // because the persisted string would no longer round-trip.
        assertEquals("system", ThemeMode.System.storageKey)
        assertEquals("light", ThemeMode.Light.storageKey)
        assertEquals("dark", ThemeMode.Dark.storageKey)
    }

    @Test fun `fromKey round-trips every known mode`() {
        ThemeMode.entries.forEach { mode ->
            assertEquals(mode, ThemeMode.fromKey(mode.storageKey))
        }
    }

    @Test fun `unknown or null key falls back to Light, not System`() {
        // Deliberate: a fresh install with no stored value lands on Light
        // rather than System so the splash flash never looks black on a
        // device whose system theme defaults to dark. Keep this pinned
        // unless we revisit that design call.
        assertEquals(ThemeMode.Light, ThemeMode.fromKey(null))
        assertEquals(ThemeMode.Light, ThemeMode.fromKey(""))
        assertEquals(ThemeMode.Light, ThemeMode.fromKey("auto"))
    }
}
