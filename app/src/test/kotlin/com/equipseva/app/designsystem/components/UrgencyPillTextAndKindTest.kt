package com.equipseva.app.designsystem.components

import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Pins the [RepairJobUrgency] → (label, [PillKind]) mapping behind
 * UrgencyPill. The tone gradient is intentional:
 *
 *   Emergency → Danger    (red - call now)
 *   SameDay   → Warn      (amber - same day delivery)
 *   Scheduled → Info      (blue - planned)
 *   Unknown   → Neutral   (softened to "Standard" copy)
 *
 * A regression that promoted Unknown to Warn would surface a yellow
 * pill on legacy rows that have no urgency set — visual noise across
 * the entire job board.
 */
class UrgencyPillTextAndKindTest {

    @Test fun `Emergency renders Danger tone with Emergency label`() {
        val (text, kind) = urgencyPillTextAndKind(RepairJobUrgency.Emergency)
        assertEquals("Emergency", text)
        assertEquals(PillKind.Danger, kind)
    }

    @Test fun `SameDay renders the Same day label with Warn tone`() {
        // Two-word label with a space — matches the UX copy
        // ("Need same-day visit") rather than the storage-key form.
        val (text, kind) = urgencyPillTextAndKind(RepairJobUrgency.SameDay)
        assertEquals("Same day", text)
        assertEquals(PillKind.Warn, kind)
    }

    @Test fun `Scheduled renders Info tone`() {
        val (text, kind) = urgencyPillTextAndKind(RepairJobUrgency.Scheduled)
        assertEquals("Scheduled", text)
        assertEquals(PillKind.Info, kind)
    }

    @Test fun `Unknown is softened to Standard label with Neutral tone`() {
        // UX softening — a legacy row with no urgency set still
        // shows SOMETHING but in a neutral colour. Pin so the
        // "Standard" copy doesn't drift back to "Unknown".
        val (text, kind) = urgencyPillTextAndKind(RepairJobUrgency.Unknown)
        assertEquals("Standard", text)
        assertEquals(PillKind.Neutral, kind)
    }

    @Test fun `every RepairJobUrgency has a non-blank label`() {
        RepairJobUrgency.entries.forEach { urgency ->
            val (text, _) = urgencyPillTextAndKind(urgency)
            assertFalse("${urgency.name} has blank label", text.isBlank())
        }
    }

    @Test fun `all four urgency labels are distinct`() {
        val labels = RepairJobUrgency.entries.map { urgencyPillTextAndKind(it).first }
        assertEquals(labels.size, labels.toSet().size)
    }
}
