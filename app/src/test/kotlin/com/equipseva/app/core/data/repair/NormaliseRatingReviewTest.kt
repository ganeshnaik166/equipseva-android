package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the rating-review normaliser. The repository runs every
 * inbound review through this before persisting. Three guards:
 *
 *   1) Trim whitespace — a copy-paste padded with spaces shouldn't
 *      surface as " " on the engineer directory card.
 *   2) Cap at 1000 chars — pasted blobs would bloat the directory
 *      card's review preview row and wedge the layout (was a real
 *      regression before the cap landed).
 *   3) All-whitespace folds to null — keep the column NULL rather
 *      than storing "    " as a "review".
 */
class NormaliseRatingReviewTest {

    @Test fun `null input passes through unchanged`() {
        assertNull(normaliseRatingReview(null))
    }

    @Test fun `empty input folds to null`() {
        assertNull(normaliseRatingReview(""))
    }

    @Test fun `whitespace-only input folds to null`() {
        // Critical: the column must be NULL, not " ", so the
        // "has-review" gate downstream correctly skips rendering.
        assertNull(normaliseRatingReview("   "))
        assertNull(normaliseRatingReview("\n\t  \n"))
    }

    @Test fun `normal review passes through after trim`() {
        assertEquals(
            "Excellent service",
            normaliseRatingReview("  Excellent service  "),
        )
    }

    @Test fun `review at exactly 1000 chars is preserved`() {
        // Boundary — caller already at the cap stays valid.
        val text = "x".repeat(1000)
        assertEquals(text, normaliseRatingReview(text))
    }

    @Test fun `review longer than 1000 chars is truncated`() {
        val text = "y".repeat(1001)
        val out = normaliseRatingReview(text)
        assertEquals(1000, out?.length)
    }

    @Test fun `review padded with whitespace and then long gets trimmed THEN capped`() {
        // Trim first removes the leading/trailing whitespace, then
        // take(1000) caps. Pin so a refactor doesn't swap the order
        // (which would let "   " + 1001 chars through as 1000+
        // trimmed length).
        val padded = "   " + "x".repeat(1001) + "   "
        val out = normaliseRatingReview(padded)
        assertEquals(1000, out?.length)
    }

    @Test fun `review with newlines inside is preserved`() {
        val text = "Two\nthree\nline review"
        assertEquals(text, normaliseRatingReview(text))
    }

    @Test fun `review with leading newlines is trimmed`() {
        // Kotlin's trim() strips both leading + trailing whitespace
        // characters including \n. Pin so a refactor doesn't switch
        // to trimEnd() only.
        assertEquals(
            "Real review here",
            normaliseRatingReview("\n\n  Real review here  \n"),
        )
    }
}
