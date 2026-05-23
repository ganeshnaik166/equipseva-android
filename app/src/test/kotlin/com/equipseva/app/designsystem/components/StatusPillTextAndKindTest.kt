package com.equipseva.app.designsystem.components

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the [RepairJobStatus] → (label, [PillKind]) mapping behind
 * StatusPill. The label copy + pill tone is the cross-surface badge
 * shown on the job board, my-bids, active-work, and detail header —
 * a regression in any branch would silently leak across all of them.
 *
 * Two tone choices worth defending:
 *   * Assigned + EnRoute both render Warn — engineer-side urgent
 *     "act on this" tone (kept distinct from InProgress's Lime
 *     "work happening" tone).
 *   * Cancelled + Disputed both render Danger — terminal-failure
 *     tone. Pin so a future "soften disputes to Warn" change is
 *     intentional.
 */
class StatusPillTextAndKindTest {

    @Test fun `Requested renders the open-for-bidding tone`() {
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.Requested)
        assertEquals("Requested", text)
        assertEquals(PillKind.Info, kind)
    }

    @Test fun `Assigned renders Warn tone`() {
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.Assigned)
        assertEquals("Assigned", text)
        assertEquals(PillKind.Warn, kind)
    }

    @Test fun `EnRoute renders En route label with Warn tone`() {
        // Two-word label with a space — pin so a future condense
        // ("EnRoute" / "En-route") is intentional.
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.EnRoute)
        assertEquals("En route", text)
        assertEquals(PillKind.Warn, kind)
    }

    @Test fun `InProgress renders Lime tone (distinct from Warn)`() {
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.InProgress)
        assertEquals("In progress", text)
        assertEquals(PillKind.Lime, kind)
    }

    @Test fun `Completed renders Success tone`() {
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.Completed)
        assertEquals("Completed", text)
        assertEquals(PillKind.Success, kind)
    }

    @Test fun `Cancelled and Disputed both render Danger tone`() {
        val cancelled = statusPillTextAndKind(RepairJobStatus.Cancelled)
        val disputed = statusPillTextAndKind(RepairJobStatus.Disputed)
        assertEquals("Cancelled", cancelled.first)
        assertEquals(PillKind.Danger, cancelled.second)
        assertEquals("Disputed", disputed.first)
        assertEquals(PillKind.Danger, disputed.second)
    }

    @Test fun `Unknown renders Neutral tone`() {
        // Defensive — a server-side enum addition that the client
        // doesn't know about should NOT borrow another tone (no
        // false-Success on something we can't classify).
        val (text, kind) = statusPillTextAndKind(RepairJobStatus.Unknown)
        assertEquals("Unknown", text)
        assertEquals(PillKind.Neutral, kind)
    }

    @Test fun `every RepairJobStatus has a unique label`() {
        // Pin so a future copy edit doesn't accidentally make two
        // statuses indistinguishable.
        val labels = RepairJobStatus.entries.map { statusPillTextAndKind(it).first }
        assertEquals(labels.size, labels.toSet().size)
    }

    @Test fun `every RepairJobStatus is covered by the when (no else branch)`() {
        // The mapping is an exhaustive when — adding a new enum value
        // forces a compile error in `statusPillTextAndKind`. This test
        // exists as a smoke check: every entry must produce a non-blank
        // label and a non-null PillKind.
        RepairJobStatus.entries.forEach { status ->
            val (text, _) = statusPillTextAndKind(status)
            assertEquals("${status.name} label should be non-blank", false, text.isBlank())
        }
    }
}
