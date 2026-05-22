package com.equipseva.app.features.profile

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the engineer-suspension banner copy + timestamp formatter.
 *
 * Two regions worth pinning:
 *   * engineerSuspensionReason: singular/plural split on flag count.
 *     A regression to always-interpolating the count would surface
 *     "1 flags" on the most common one-strike case.
 *   * formatSuspensionTimestamp: replaces ISO 'T' with space so the
 *     "Paused: …" line reads naturally rather than as machine
 *     output.
 */
class EngineerSuspensionCopyTest {

    // ---- engineerSuspensionReason ----

    @Test fun `explicit reason from server wins (no fallback composition)`() {
        val out = engineerSuspensionReason(
            explicitReason = "Admin paused after duplicate Aadhaar",
            flagCount90d = 3,
        )
        assertEquals("Admin paused after duplicate Aadhaar", out)
    }

    @Test fun `singular flag count uses 1 hospital cash-payment flag (no plural)`() {
        val out = engineerSuspensionReason(explicitReason = null, flagCount90d = 1)
        assertEquals(
            "1 hospital cash-payment flag in the last 90 days. " +
                "EquipSeva paused your availability while we review.",
            out,
        )
    }

    @Test fun `plural flag count uses N flags (3+)`() {
        val out = engineerSuspensionReason(explicitReason = null, flagCount90d = 3)
        assertEquals(
            "3 hospital cash-payment flags in the last 90 days. " +
                "EquipSeva paused your availability while we review.",
            out,
        )
    }

    @Test fun `zero flag count uses plural shape (defensive — caller doesn't suspend on 0)`() {
        // Suspension shouldn't trigger at 0 flags, but pin a sensible
        // fallback so the helper is total.
        val out = engineerSuspensionReason(explicitReason = null, flagCount90d = 0)
        assertEquals(
            "0 hospital cash-payment flags in the last 90 days. " +
                "EquipSeva paused your availability while we review.",
            out,
        )
    }

    @Test fun `empty string reason is treated as explicit (not blank-coerced)`() {
        // Defensive — if the server emits an empty string explicitly,
        // surface it as-is rather than overriding with the generic
        // copy. (A future refactor that coerced blank → null would
        // surface in review.)
        val out = engineerSuspensionReason(explicitReason = "", flagCount90d = 5)
        assertEquals("", out)
    }

    // ---- formatSuspensionTimestamp ----

    @Test fun `replaces T separator with space and truncates to seconds precision`() {
        // Full ISO 8601 — takes first 19 chars, swaps T for space.
        assertEquals(
            "2026-05-21 10:42:13",
            formatSuspensionTimestamp("2026-05-21T10:42:13.123456Z"),
        )
    }

    @Test fun `19-char input (no fractional seconds) passes through unchanged except T swap`() {
        assertEquals(
            "2026-05-21 10:42:13",
            formatSuspensionTimestamp("2026-05-21T10:42:13"),
        )
    }

    @Test fun `short input takes whatever is there (defensive)`() {
        // A server-side rename to a shorter format should still render
        // SOMETHING rather than crash.
        assertEquals("2026-05-21", formatSuspensionTimestamp("2026-05-21"))
    }

    @Test fun `no T separator returns the truncated input as-is`() {
        assertEquals(
            "2026-05-21 10:42:13",
            formatSuspensionTimestamp("2026-05-21 10:42:13"),
        )
    }

    @Test fun `empty input returns empty (no crash)`() {
        assertEquals("", formatSuspensionTimestamp(""))
    }
}
