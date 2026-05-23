package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the site-location text composition that lands in
 * `repair_jobs.site_location`. Two-line labelled format that the
 * engineer reads on the job card / detail screen.
 *
 * Critical: blank fields fold OUT entirely — a label without a value
 * ("Address: \nNotes: actual notes") would read as a bug. Pin the
 * trim-before-checking-blank semantics.
 */
class ComposeSiteLocationTest {

    @Test fun `both fields present produces two-line labelled output`() {
        assertEquals(
            "Address: 23/A Park Street\nNotes: Side gate near loading bay",
            composeSiteLocation(
                siteAddress = "23/A Park Street",
                siteNotes = "Side gate near loading bay",
            ),
        )
    }

    @Test fun `only address yields single Address line`() {
        assertEquals(
            "Address: 23/A Park Street",
            composeSiteLocation(siteAddress = "23/A Park Street", siteNotes = ""),
        )
    }

    @Test fun `only notes yields single Notes line`() {
        assertEquals(
            "Notes: Side gate",
            composeSiteLocation(siteAddress = "", siteNotes = "Side gate"),
        )
    }

    @Test fun `both blank yields null (no empty labels)`() {
        assertNull(composeSiteLocation(siteAddress = "", siteNotes = ""))
    }

    @Test fun `whitespace-only fields are treated as blank`() {
        assertNull(composeSiteLocation(siteAddress = "   ", siteNotes = "\t\n"))
    }

    @Test fun `fields are trimmed before labelling`() {
        // Leading/trailing whitespace from paste shouldn't leak into
        // the labelled output.
        assertEquals(
            "Address: 23/A Park Street\nNotes: Side gate",
            composeSiteLocation(
                siteAddress = "   23/A Park Street   ",
                siteNotes = "  Side gate  ",
            ),
        )
    }

    @Test fun `blank address with non-blank notes does not produce empty Address line`() {
        // A regression that fell back to "Address: \nNotes: ..." would
        // surface a bare label on the engineer's job card.
        val out = composeSiteLocation(siteAddress = "  ", siteNotes = "Side gate")
        assertEquals("Notes: Side gate", out)
        assert(!out!!.contains("Address:"))
    }

    @Test fun `non-blank notes with blank address keeps Notes label (symmetric)`() {
        // Symmetric to the blank-address-only case. Pin so a refactor
        // that reordered the listOfNotNull doesn't surface a labelled
        // empty line in one direction but not the other.
        val out = composeSiteLocation(siteAddress = "  ", siteNotes = "Loading bay")
        assertEquals("Notes: Loading bay", out)
        assert(!out!!.contains("Address:"))
    }

    @Test fun `multi-line input in either field is preserved inside the label`() {
        // The picker / autocomplete can hand a multi-line address back;
        // the inner newline is kept (only the outer join-on-newline is
        // controlled by the composer).
        val out = composeSiteLocation(
            siteAddress = "Block A\nFloor 3",
            siteNotes = "Side gate",
        )
        assertEquals("Address: Block A\nFloor 3\nNotes: Side gate", out)
    }
}
