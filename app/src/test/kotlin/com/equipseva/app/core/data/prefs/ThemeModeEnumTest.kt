package com.equipseva.app.core.data.prefs

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the [ThemeMode] wire-string contract. The keys are stored
 * verbatim in DataStore, so a rename would orphan every existing
 * device's persisted theme choice (next read would fall through to
 * the Light fallback regardless of what the user picked).
 *
 * Light is the fallback (not System) because the app launched as
 * Light-only; the System option shipped later and we don't want
 * existing users with no key set to suddenly switch to dark on a
 * system-dark device.
 */
class ThemeModeEnumTest {

    @Test fun `keys match the pinned DataStore strings`() {
        assertEquals("system", ThemeMode.System.storageKey)
        assertEquals("light", ThemeMode.Light.storageKey)
        assertEquals("dark", ThemeMode.Dark.storageKey)
    }

    @Test fun `fromKey resolves known keys`() {
        assertEquals(ThemeMode.System, ThemeMode.fromKey("system"))
        assertEquals(ThemeMode.Light, ThemeMode.fromKey("light"))
        assertEquals(ThemeMode.Dark, ThemeMode.fromKey("dark"))
    }

    @Test fun `fromKey null falls back to Light (not System)`() {
        // Light is the conservative fallback — existing users who
        // installed before the System option shipped (no key in
        // DataStore) keep their Light experience instead of
        // suddenly switching to dark on a system-dark device.
        assertEquals(ThemeMode.Light, ThemeMode.fromKey(null))
    }

    @Test fun `fromKey unknown key falls back to Light`() {
        assertEquals(ThemeMode.Light, ThemeMode.fromKey("future_theme"))
    }

    @Test fun `fromKey is strict on case (lowercase contract)`() {
        // DataStore writes lowercase; uppercase isn't a valid key.
        assertEquals(ThemeMode.Light, ThemeMode.fromKey("DARK"))
    }

    @Test fun `three theme modes total`() {
        assertEquals(3, ThemeMode.entries.size)
    }
}
