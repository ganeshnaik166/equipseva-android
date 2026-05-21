package com.equipseva.app.core.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [DeviceIntegrityCheck.Verdict] derivations:
 *
 *   * `clean` flips false if ANY of the four signals trip. A
 *     regression that softened the check (e.g. requiring 2+ signals)
 *     would let through a rooted-but-not-emulator device.
 *   * `toTag()` produces the exact log-line shape the founder
 *     Integrity dashboard greps for. Pin the labels.
 *
 * The Verdict itself is constructed by the JVM-side `run()` which
 * needs Android Context for the runtime probes; tests here exercise
 * only the pure data-class derivations, which are platform-free.
 */
class DeviceIntegrityVerdictTest {

    @Test fun `all four flags false yields clean true`() {
        val v = DeviceIntegrityCheck.Verdict(
            debuggerAttached = false,
            rooted = false,
            emulator = false,
            fridaDetected = false,
        )
        assertTrue(v.clean)
    }

    @Test fun `any one flag true taints the clean flag`() {
        // Pin each branch independently — a regression that softened
        // (e.g. needs both rooted AND frida) would silently permit
        // single-signal compromises.
        assertFalse(
            DeviceIntegrityCheck.Verdict(true, false, false, false).clean,
        )
        assertFalse(
            DeviceIntegrityCheck.Verdict(false, true, false, false).clean,
        )
        assertFalse(
            DeviceIntegrityCheck.Verdict(false, false, true, false).clean,
        )
        assertFalse(
            DeviceIntegrityCheck.Verdict(false, false, false, true).clean,
        )
    }

    @Test fun `multiple flags true keeps clean false`() {
        val v = DeviceIntegrityCheck.Verdict(true, true, true, true)
        assertFalse(v.clean)
    }

    @Test fun `toTag produces the exact log-line shape`() {
        val v = DeviceIntegrityCheck.Verdict(
            debuggerAttached = false,
            rooted = true,
            emulator = false,
            fridaDetected = true,
        )
        assertEquals(
            "debugger=false rooted=true emulator=false frida=true",
            v.toTag(),
        )
    }

    @Test fun `toTag is space-delimited and includes every signal`() {
        val v = DeviceIntegrityCheck.Verdict(false, false, false, false)
        val tag = v.toTag()
        assertTrue("missing debugger", tag.contains("debugger="))
        assertTrue("missing rooted", tag.contains("rooted="))
        assertTrue("missing emulator", tag.contains("emulator="))
        assertTrue("missing frida", tag.contains("frida="))
        // Four signals + three separators → exactly three spaces.
        assertEquals(3, tag.count { it == ' ' })
    }
}
