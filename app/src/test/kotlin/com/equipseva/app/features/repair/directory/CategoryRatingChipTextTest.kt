package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the per-category rating chip composer on EngineerPublicProfile.
 *
 * Critical region: ratingAvg formats under Locale.US so a Hindi-
 * locale device doesn't surface "4,8" (comma-decimal) which reads
 * as "4 to 8" or a list to the user.
 */
class CategoryRatingChipTextTest {

    @Test fun `happy path composes prettied category + count + rating`() {
        assertEquals(
            "Imaging Radiology · 7 · 4.8★",
            categoryRatingChipText(
                categoryKey = "imaging_radiology",
                reviewCount = 7,
                ratingAvg = 4.8,
            ),
        )
    }

    @Test fun `category key is prettified via prettyKey (snake_case to Title Case)`() {
        // Pin so a refactor that dropped prettyKey doesn't surface
        // raw snake_case to users.
        val out = categoryRatingChipText(
            categoryKey = "patient_monitoring",
            reviewCount = 3,
            ratingAvg = 4.5,
        )
        assertEquals(true, out.startsWith("Patient Monitoring"))
    }

    @Test fun `rating is formatted to 1 decimal place`() {
        // 4.0 → "4.0" (trailing zero pinned — chip is fixed-width
        // visual context; dropping the .0 would shift the star
        // glyph and break alignment in a horizontal scroll).
        assertEquals(
            "Imaging · 1 · 4.0★",
            categoryRatingChipText("imaging", 1, 4.0),
        )
        // 4.85 → rounds to "4.9" via printf semantics.
        assertEquals(
            "Imaging · 1 · 4.9★",
            categoryRatingChipText("imaging", 1, 4.85),
        )
    }

    @Test fun `rating uses Locale-US dot decimal (not comma)`() {
        // Critical — pin so a refactor that dropped Locale.US doesn't
        // accidentally surface "4,8" on Hindi-locale devices.
        val out = categoryRatingChipText("imaging", 1, 4.8)
        assertEquals(true, out.contains("4.8"))
        assertEquals(false, out.contains("4,8"))
    }

    @Test fun `star glyph is the white-star (U+2605)`() {
        // ★ is U+2605 BLACK STAR (actually filled). Pin so a future
        // ascii-only refactor surfaces.
        val out = categoryRatingChipText("imaging", 1, 4.8)
        assertEquals(true, out.contains('★'))
    }

    @Test fun `middle-dot separator pinned (U+00B7, not ASCII)`() {
        val out = categoryRatingChipText("imaging", 1, 4.8)
        // Two middle-dot separators between the three segments.
        val count = out.count { it == '·' }
        assertEquals(2, count)
    }

    @Test fun `large review count interpolates verbatim`() {
        assertEquals(
            "Imaging · 999 · 4.7★",
            categoryRatingChipText("imaging", 999, 4.7),
        )
    }

    @Test fun `zero rating renders as 0_0 star (defensive — caller usually filters)`() {
        // The summary band typically hides 0-rating rows, but pin
        // a sensible total fallback.
        assertEquals(
            "Imaging · 0 · 0.0★",
            categoryRatingChipText("imaging", 0, 0.0),
        )
    }
}
