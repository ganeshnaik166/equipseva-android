package com.equipseva.app.designsystem.components

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `statusPillContent` is the single source of truth for the status badge
 * shown on the job board, my-bids, active-work, and the repair detail
 * header. Drift here means the same job tells the hospital one story and
 * the engineer another — these tests pin the exact label + colour bucket
 * for every enum case (including the catch-all Unknown) so a future enum
 * addition can't slip past unmapped.
 */
class StatusPillContentTest {

    @Test fun `Requested maps to Info tone with label Requested`() {
        // Open-for-bidding jobs use the neutral Info blue; not warn/danger
        // because there's no time pressure baked into "requested".
        val (label, kind) = statusPillContent(RepairJobStatus.Requested)
        assertEquals("Requested", label)
        assertEquals(PillKind.Info, kind)
    }

    @Test fun `Assigned maps to Warn tone`() {
        // An assigned job is mid-flight — engineer picked, hospital
        // waiting; Warn (amber) signals "in motion, not done yet".
        val (label, kind) = statusPillContent(RepairJobStatus.Assigned)
        assertEquals("Assigned", label)
        assertEquals(PillKind.Warn, kind)
    }

    @Test fun `EnRoute maps to Warn tone with two-word label`() {
        // The display string must be "En route" (space) not "EnRoute"
        // (PascalCase enum name leakage) — pin the human label.
        val (label, kind) = statusPillContent(RepairJobStatus.EnRoute)
        assertEquals("En route", label)
        assertEquals(PillKind.Warn, kind)
    }

    @Test fun `InProgress maps to Lime tone`() {
        // Lime (not Warn) distinguishes active hands-on work from
        // "engineer is on the way" — the only state that uses Lime.
        val (label, kind) = statusPillContent(RepairJobStatus.InProgress)
        assertEquals("In progress", label)
        assertEquals(PillKind.Lime, kind)
    }

    @Test fun `Completed maps to Success tone`() {
        val (label, kind) = statusPillContent(RepairJobStatus.Completed)
        assertEquals("Completed", label)
        assertEquals(PillKind.Success, kind)
    }

    @Test fun `Cancelled maps to Danger tone`() {
        // Cancelled and Disputed share the Danger bucket because both
        // surfaces in lists need to be visually distinguishable from
        // happy-path closure (Completed). Pin Danger explicitly so a
        // refactor doesn't quietly demote them to Neutral.
        val (label, kind) = statusPillContent(RepairJobStatus.Cancelled)
        assertEquals("Cancelled", label)
        assertEquals(PillKind.Danger, kind)
    }

    @Test fun `Disputed maps to Danger tone`() {
        val (label, kind) = statusPillContent(RepairJobStatus.Disputed)
        assertEquals("Disputed", label)
        assertEquals(PillKind.Danger, kind)
    }

    @Test fun `Unknown falls back to Neutral with placeholder label`() {
        // Server-side enum drift (a new status the app doesn't know
        // about) hits this branch. Neutral + "Unknown" is the safe
        // visual default — never crash, never imply a state the app
        // can't reason about.
        val (label, kind) = statusPillContent(RepairJobStatus.Unknown)
        assertEquals("Unknown", label)
        assertEquals(PillKind.Neutral, kind)
    }

    @Test fun `every RepairJobStatus enum value has a mapping`() {
        // Belt-and-braces: forEach over the enum so an additional case
        // added to RepairJobStatus without updating this mapper would
        // become a compile-error inside the when, but this test also
        // catches accidental returns of empty strings.
        RepairJobStatus.entries.forEach { status ->
            val (label, _) = statusPillContent(status)
            assert(label.isNotBlank()) { "$status produced a blank pill label" }
        }
    }
}
