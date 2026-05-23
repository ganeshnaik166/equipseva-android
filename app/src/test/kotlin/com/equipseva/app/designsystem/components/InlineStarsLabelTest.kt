package com.equipseva.app.designsystem.components

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * Pins the rating + count labels in InlineStars. Critical regression
 * target: Locale.US stability on the rating decimal so Hindi / German
 * / French locale devices don't render "4,8" (which reads as "4 to 8"
 * or a list of ratings).
 */
class InlineStarsLabelTest {

    // ---- inlineStarsRatingLabel --------------------------------------

    @Test fun `rating formats with one decimal place`() {
        assertEquals("4.8", inlineStarsRatingLabel(4.8))
    }

    @Test fun `whole-number rating still shows one decimal`() {
        // Pin %.1f over %g — "5.0" not "5" so all rows align visually.
        assertEquals("5.0", inlineStarsRatingLabel(5.0))
    }

    @Test fun `rating rounds to one decimal half-up`() {
        assertEquals("3.3", inlineStarsRatingLabel(3.25))
        assertEquals("4.7", inlineStarsRatingLabel(4.65))
    }

    @Test fun `formatter is Locale-US stable, not device-locale`() {
        // Critical regression target — set+restore default locale.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals("4.8", inlineStarsRatingLabel(4.8))
            Locale.setDefault(Locale.GERMANY)
            assertEquals("4.8", inlineStarsRatingLabel(4.8))
            Locale.setDefault(Locale.forLanguageTag("fr-FR"))
            assertEquals("4.8", inlineStarsRatingLabel(4.8))
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `zero rating reads 0_0 (caller can gate but pin total shape)`() {
        assertEquals("0.0", inlineStarsRatingLabel(0.0))
    }

    // ---- inlineStarsCountLabel ---------------------------------------

    @Test fun `count is wrapped in parens`() {
        assertEquals("(42)", inlineStarsCountLabel(42))
    }

    @Test fun `zero count reads (0)`() {
        assertEquals("(0)", inlineStarsCountLabel(0))
    }

    @Test fun `count 1 still uses parens (no special case)`() {
        // Pin no singular/plural — the format is just (N).
        assertEquals("(1)", inlineStarsCountLabel(1))
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals("(9999)", inlineStarsCountLabel(9999))
    }
}
