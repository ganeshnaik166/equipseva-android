package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InactiveEngineerRowHelpersTest {

    // ---- inactiveEngineerActivityPill --------------------------------

    @Test fun `null last-released reads Never shipped with Danger`() {
        // Loudest signal — never shipped.
        assertEquals(
            "Never shipped" to PillKind.Danger,
            inactiveEngineerActivityPill(null),
        )
    }

    @Test fun `89 days reads N days quiet with Warn`() {
        assertEquals(
            "89d quiet" to PillKind.Warn,
            inactiveEngineerActivityPill(89L),
        )
    }

    @Test fun `90 days (boundary INCLUSIVE) reads N days quiet with Danger`() {
        // Critical pin — 90 is inclusive for Danger. A refactor to
        // > 90 (exclusive) would silently soften the queue.
        assertEquals(
            "90d quiet" to PillKind.Danger,
            inactiveEngineerActivityPill(90L),
        )
    }

    @Test fun `91 days reads N days quiet with Danger`() {
        assertEquals(
            "91d quiet" to PillKind.Danger,
            inactiveEngineerActivityPill(91L),
        )
    }

    @Test fun `large days reads N days quiet with Danger`() {
        assertEquals(
            "365d quiet" to PillKind.Danger,
            inactiveEngineerActivityPill(365L),
        )
    }

    @Test fun `0 days reads N days quiet with Warn`() {
        // Defensive — same-day-released but still flagged inactive
        // (rare; pin the helper stays total).
        assertEquals(
            "0d quiet" to PillKind.Warn,
            inactiveEngineerActivityPill(0L),
        )
    }

    @Test fun `Never shipped literal is preserved over generic Inactive`() {
        // Pin literal — "Never shipped" is structurally distinct
        // from "gone quiet"; a refactor to "Inactive" would lose
        // the load-bearing distinction.
        val (text, _) = inactiveEngineerActivityPill(null)
        assertEquals("Never shipped", text)
    }

    // ---- inactiveEngineerLocationLine --------------------------------

    @Test fun `both city and state join with comma-space`() {
        assertEquals(
            "Hyderabad, Telangana",
            inactiveEngineerLocationLine("Hyderabad", "Telangana"),
        )
    }

    @Test fun `city alone passes through`() {
        assertEquals(
            "Hyderabad",
            inactiveEngineerLocationLine("Hyderabad", null),
        )
    }

    @Test fun `state alone passes through`() {
        assertEquals(
            "Telangana",
            inactiveEngineerLocationLine(null, "Telangana"),
        )
    }

    @Test fun `both null returns null (caller hides Text)`() {
        assertNull(inactiveEngineerLocationLine(null, null))
    }

    @Test fun `both empty strings surface ", " — documented quirk (caller passes null not blank)`() {
        // QUIRK: listOfNotNull keeps "" (non-null), join becomes ", "
        // which contains comma so ifBlank doesn't fire. Pin the
        // current behaviour. Backfill code should pass null, not "".
        assertEquals(", ", inactiveEngineerLocationLine("", ""))
    }

    // ---- inactiveEngineerSpecializationsPreview ----------------------

    @Test fun `empty list returns blank string`() {
        assertEquals("", inactiveEngineerSpecializationsPreview(emptyList()))
    }

    @Test fun `single spec passes through`() {
        assertEquals(
            "Imaging",
            inactiveEngineerSpecializationsPreview(listOf("Imaging")),
        )
    }

    @Test fun `three specs join all with middle dot`() {
        assertEquals(
            "Imaging · Cardiology · Anesthesia",
            inactiveEngineerSpecializationsPreview(listOf("Imaging", "Cardiology", "Anesthesia")),
        )
    }

    @Test fun `four or more specs are truncated to first three`() {
        // Critical pin — take(3) keeps the row visually tight.
        assertEquals(
            "Imaging · Cardiology · Anesthesia",
            inactiveEngineerSpecializationsPreview(
                listOf("Imaging", "Cardiology", "Anesthesia", "Neuro", "Dental"),
            ),
        )
    }

    // ---- inactiveEngineerContactLine ---------------------------------

    @Test fun `both contacts join with middle dot`() {
        assertEquals(
            "a@b.com · +91 1",
            inactiveEngineerContactLine("a@b.com", "+91 1"),
        )
    }

    @Test fun `null contacts return blank string (no fallback string)`() {
        // Critical pin — distinct from userRowContactLine which has
        // a "no contact" fallback. Founder reactivation surface
        // gates on isBlank() instead.
        assertEquals("", inactiveEngineerContactLine(null, null))
    }

    @Test fun `email only passes through`() {
        assertEquals(
            "a@b.com",
            inactiveEngineerContactLine("a@b.com", null),
        )
    }

    @Test fun `phone only passes through`() {
        assertEquals(
            "+91 1",
            inactiveEngineerContactLine(null, "+91 1"),
        )
    }
}
