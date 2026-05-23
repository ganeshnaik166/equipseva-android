package com.equipseva.app.features.mybids

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BidRowHelpersTest {

    // ---- bidRowEquipmentTitle ----------------------------------------

    @Test fun `equipmentLabel wins when present`() {
        assertEquals(
            "Ultrasound machine",
            bidRowEquipmentTitle("Ultrasound machine", "Repair needed urgently"),
        )
    }

    @Test fun `null equipmentLabel falls through to job title`() {
        assertEquals(
            "Repair needed urgently",
            bidRowEquipmentTitle(null, "Repair needed urgently"),
        )
    }

    @Test fun `both null falls back to generic Repair job`() {
        // Pin the tap-targetable generic fallback — empty whitespace
        // on a backfill row would lose the row's tap affordance.
        assertEquals(
            "Repair job",
            bidRowEquipmentTitle(null, null),
        )
    }

    @Test fun `empty equipmentLabel still wins (exact null gate)`() {
        // Pin exact null-only gate — a refactor to isNullOrBlank
        // would silently skip an empty equipmentLabel and surface
        // the job title even when equipmentLabel="" was set.
        assertEquals("", bidRowEquipmentTitle("", "fallback title"))
    }

    // ---- queuedBidPillText -------------------------------------------

    @Test fun `count of 1 reads 1 bid queued (singular)`() {
        // Critical pin — never "1 bids queued".
        assertEquals(
            "1 bid queued — will submit when back online",
            queuedBidPillText(1),
        )
    }

    @Test fun `count of 2 reads N bids queued (plural)`() {
        assertEquals(
            "2 bids queued — will submit when back online",
            queuedBidPillText(2),
        )
    }

    @Test fun `count of 0 reads plural shape (defensive — caller gates on positive)`() {
        // The caller short-circuits on count <= 0 so this is defensive,
        // but pin the total-function shape.
        assertEquals(
            "0 bids queued — will submit when back online",
            queuedBidPillText(0),
        )
    }

    @Test fun `large count interpolates with plural`() {
        assertEquals(
            "42 bids queued — will submit when back online",
            queuedBidPillText(42),
        )
    }

    @Test fun `em-dash separator is U+2014 not U+2013 en-dash`() {
        val text = queuedBidPillText(1)
        assertTrue(text.contains('—'))
        assertEquals(false, text.contains('–'))
    }

    @Test fun `will submit when back online phrasing preserved verbatim`() {
        // Pin literal — a refactor to "will be sent" would change
        // the semantics from active to passive voice.
        assertTrue(queuedBidPillText(1).endsWith("will submit when back online"))
        assertTrue(queuedBidPillText(5).endsWith("will submit when back online"))
    }
}
