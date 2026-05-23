package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the contact line on the founder's buyer-KYC review card.
 * Critical regression target: the listOfNotNull + ifBlank double-fold
 * is what guarantees "No contact" appears on a fully-empty row instead
 * of "null · null" or a naked empty Text element that breaks the
 * card's vertical rhythm.
 */
class BuyerKycContactLineTest {

    @Test fun `both email and phone present joins with middle dot`() {
        assertEquals(
            "asha@example.com · +91 98765 43210",
            buyerKycContactLine("asha@example.com", "+91 98765 43210"),
        )
    }

    @Test fun `null email shows phone alone (no leading separator)`() {
        assertEquals(
            "+91 98765 43210",
            buyerKycContactLine(null, "+91 98765 43210"),
        )
    }

    @Test fun `null phone shows email alone (no trailing separator)`() {
        assertEquals(
            "asha@example.com",
            buyerKycContactLine("asha@example.com", null),
        )
    }

    @Test fun `both null falls back to No contact`() {
        // Critical pin — the ifBlank guard on the joined string.
        assertEquals("No contact", buyerKycContactLine(null, null))
    }

    @Test fun `both empty strings surface a naked middle-dot — documented behaviour`() {
        // QUIRK: listOfNotNull keeps "" (it's non-null), so the join
        // becomes " · " (a non-blank string containing the middle
        // dot), and ifBlank does NOT fire. This is a sharp edge in
        // the helper — backfill code should pass null not "". Pin so
        // a future fix that adds blank-folding surfaces here as a
        // deliberate behaviour change rather than slipping in.
        assertEquals(" · ", buyerKycContactLine("", ""))
    }

    @Test fun `blank email but non-blank phone shows the joined pair as-is`() {
        // listOfNotNull keeps the blank email because it's not null.
        // The resulting join surfaces as " · phone" — which is
        // visually weird but pins the helper's total shape. A refactor
        // could improve this; the test pins current behaviour.
        val line = buyerKycContactLine("   ", "+91 98765 43210")
        // Either the helper folds blank→null (best) or surfaces the
        // raw join. Pin current behaviour explicitly.
        assertEquals("    · +91 98765 43210", line)
    }

    @Test fun `middle dot is U+00B7 not ASCII period`() {
        val line = buyerKycContactLine("a@b.c", "+91 1")
        assertTrue(line.contains('·'))
    }
}
