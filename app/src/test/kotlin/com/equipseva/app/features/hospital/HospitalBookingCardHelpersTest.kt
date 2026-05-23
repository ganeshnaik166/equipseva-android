package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three helpers behind the hospital's active-job card.
 *
 * Critical surface: the right-column gate that prevents both columns
 * from duplicating "1d ago" when the left side has fallen back to a
 * "Posted Nd ago" string.
 */
class HospitalBookingCardHelpersTest {

    // ---- hospitalBookingScheduleLine ---------------------------------

    @Test fun `both date and slot present join with comma+space`() {
        assertEquals(
            "Mon 25 May, 9-11am",
            hospitalBookingScheduleLine("Mon 25 May", "9-11am"),
        )
    }

    @Test fun `null slot leaves date alone (no trailing separator)`() {
        assertEquals("Mon 25 May", hospitalBookingScheduleLine("Mon 25 May", null))
    }

    @Test fun `null date leaves slot alone (no leading separator)`() {
        assertEquals("9-11am", hospitalBookingScheduleLine(null, "9-11am"))
    }

    @Test fun `both null returns blank (caller relies on the blank gate)`() {
        // Critical pin — the caller branches on isNotBlank(). A
        // refactor that interpolated "—" between fields would flip
        // the blank gate to non-blank and break the fallback chain.
        assertEquals("", hospitalBookingScheduleLine(null, null))
    }

    // ---- hospitalBookingLeftLabel ------------------------------------

    @Test fun `non-blank schedule wins`() {
        assertEquals(
            "Mon 25 May, 9-11am",
            hospitalBookingLeftLabel("Mon 25 May, 9-11am", "2d"),
        )
    }

    @Test fun `blank schedule falls back to Posted relative ago`() {
        assertEquals(
            "Posted 2d ago",
            hospitalBookingLeftLabel("", "2d"),
        )
    }

    @Test fun `blank schedule with null relative returns null (caller hides row)`() {
        // Critical pin — the null return signals "hide the entire
        // left section" so the earlier "—" placeholder bug
        // (reading as a broken metric) doesn't return.
        assertNull(hospitalBookingLeftLabel("", null))
    }

    @Test fun `Posted prefix and ago suffix wrap the bare relative label`() {
        val out = hospitalBookingLeftLabel("", "3h")
        assertTrue(out!!.startsWith("Posted "))
        assertTrue(out.endsWith(" ago"))
    }

    @Test fun `whitespace-only schedule treated as blank`() {
        // takeIf { isNotBlank() } folds whitespace-only to null →
        // fall back to relative.
        assertEquals(
            "Posted 1d ago",
            hospitalBookingLeftLabel("   ", "1d"),
        )
    }

    // ---- hospitalBookingShouldShowPostedOnRight ----------------------

    @Test fun `non-blank schedule means show posted on right`() {
        assertTrue(hospitalBookingShouldShowPostedOnRight("Mon 25 May"))
    }

    @Test fun `blank schedule means hide posted on right (left already has Posted)`() {
        // Critical pin — preventing the duplicate "1d ago" on both
        // columns when the left fell back to "Posted 1d ago".
        assertFalse(hospitalBookingShouldShowPostedOnRight(""))
        assertFalse(hospitalBookingShouldShowPostedOnRight("   "))
    }
}
