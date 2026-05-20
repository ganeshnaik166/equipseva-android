package com.equipseva.app.features.repair.components

import com.equipseva.app.core.data.repair.CostRevision
import com.equipseva.app.core.data.repair.CostRevisionStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Banner subtitle is the hospital's first signal of how much the engineer
 * wants to revise the contract by. Drift in the format (missing arrow,
 * swapped amounts, dropped "Tap to review" affordance) causes a hospital
 * to either miss the banner or misread the delta. These tests pin the
 * exact glue between [formatRupees] calls and the arrow.
 */
class CostRevisionBannerSubtitleTest {

    @Test fun `subtitle uses arrow glyph between original and revised`() {
        // The arrow glyph (→) is the one visual cue that conveys
        // "going from X to Y" without screen-reader-hostile copy like
        // "from … to …". Keep it literal.
        val text = costRevisionBannerSubtitle(revision(1000.0, 1500.0))
        assertTrue("missing arrow glyph in: $text", " → " in text)
    }

    @Test fun `subtitle starts with the original amount and ends with the tap hint`() {
        // Order matters: original first, revised second, then a clear
        // call to open the decision sheet. Pin so a refactor can't
        // accidentally show "₹1,500 → ₹1,000" or drop the tap hint.
        val text = costRevisionBannerSubtitle(revision(1000.0, 1500.0))
        assertTrue(text.startsWith("₹1,000"))
        assertTrue(text.endsWith(". Tap to review."))
    }

    @Test fun `subtitle formats rupees with no paise and a grouping comma`() {
        // formatRupees normalises to whole rupees + Indian-locale
        // grouping. The exact grouping pattern (1,00,000 lakh vs
        // 100,000 Western) depends on the JDK's en-IN locale data —
        // older JDKs ship Western grouping under en-IN. The assertion
        // only requires ₹ + at least one grouping comma + no paise,
        // not the exact lakh-vs-Western position.
        val text = costRevisionBannerSubtitle(revision(50_000.0, 1_00_000.0))
        assertTrue("expected ₹ prefix in: $text", "₹" in text)
        assertTrue("expected grouping comma in: $text", "," in text)
        assertTrue("expected no paise in: $text", ".00" !in text)
    }

    @Test fun `subtitle handles zero original amount without crashing`() {
        // Defensive: the server-side propose_cost_revision guards against
        // an original of zero, but the banner must still render
        // something sensible if a stale row sneaks through. Just pin
        // that we get a non-empty string with the revised amount.
        val text = costRevisionBannerSubtitle(revision(0.0, 1500.0))
        assertTrue(text.isNotBlank())
        assertTrue("₹1,500" in text)
    }

    @Test fun `subtitle preserves revised amount when it is lower than original`() {
        // The server allows engineers to revise downward (rare but
        // possible — engineer realised the parts cost less). Banner
        // should still show both numbers in original-then-revised
        // order, not reorder by magnitude.
        val text = costRevisionBannerSubtitle(revision(2000.0, 1500.0))
        assertTrue(text.startsWith("₹2,000"))
        assertTrue("₹1,500" in text.removePrefix("₹2,000"))
    }

    private fun revision(original: Double, revised: Double): CostRevision = CostRevision(
        id = "id",
        repairJobId = "job",
        engineerUserId = "eng",
        originalAmountRupees = original,
        revisedAmountRupees = revised,
        reason = "needs more parts",
        status = CostRevisionStatus.Proposed,
        createdAt = null,
        decidedAt = null,
        decisionBy = null,
    )

    @Test fun `subtitle exact string for a typical case matches the pinned format`() {
        // End-to-end pin of the exact string to catch any drift in the
        // glue (extra space, missing period, lost arrow padding).
        assertEquals(
            "₹1,000 → ₹1,500. Tap to review.",
            costRevisionBannerSubtitle(revision(1000.0, 1500.0)),
        )
    }
}
