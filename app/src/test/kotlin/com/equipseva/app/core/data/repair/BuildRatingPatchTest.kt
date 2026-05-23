package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the (role, stars, review) → RepairJobRatingPatchDto composition
 * used by the rating-submit path on RepairJobDetail. The patch is
 * sparse — only the rater's side of the row is written so the
 * counterparty's rating isn't clobbered on the same UPDATE. A
 * regression that filled both pairs would silently mis-attribute
 * ratings on a contested job.
 *
 *   * stars validated in [1, 5] (matches server CHECK)
 *   * review piped through normaliseRatingReview (blank → null)
 */
class BuildRatingPatchTest {

    @Test fun `hospital role writes only hospital fields`() {
        val patch = buildRatingPatch(
            role = RatingRole.HospitalRatesEngineer,
            stars = 5,
            review = "Quick and tidy",
        )
        assertEquals(5, patch.hospitalRating)
        assertEquals("Quick and tidy", patch.hospitalReview)
        // Critical: engineer-side fields stay null so the engineer's
        // own rating of the hospital isn't clobbered on this UPDATE.
        assertNull(patch.engineerRating)
        assertNull(patch.engineerReview)
    }

    @Test fun `engineer role writes only engineer fields`() {
        val patch = buildRatingPatch(
            role = RatingRole.EngineerRatesHospital,
            stars = 4,
            review = "Smooth coordination",
        )
        assertEquals(4, patch.engineerRating)
        assertEquals("Smooth coordination", patch.engineerReview)
        assertNull(patch.hospitalRating)
        assertNull(patch.hospitalReview)
    }

    @Test fun `blank review folds to null on either side`() {
        val hospital = buildRatingPatch(RatingRole.HospitalRatesEngineer, 4, "  ")
        assertNull(hospital.hospitalReview)
        val engineer = buildRatingPatch(RatingRole.EngineerRatesHospital, 4, "")
        assertNull(engineer.engineerReview)
    }

    @Test fun `null review stays null on either side`() {
        val hospital = buildRatingPatch(RatingRole.HospitalRatesEngineer, 5, null)
        assertNull(hospital.hospitalReview)
    }

    @Test fun `review over 1000 chars is truncated to the server cap`() {
        val long = "x".repeat(1500)
        val patch = buildRatingPatch(RatingRole.HospitalRatesEngineer, 5, long)
        assertEquals(1000, patch.hospitalReview?.length)
    }

    @Test fun `stars at boundaries (1 and 5) are accepted`() {
        assertEquals(1, buildRatingPatch(RatingRole.HospitalRatesEngineer, 1, null).hospitalRating)
        assertEquals(5, buildRatingPatch(RatingRole.HospitalRatesEngineer, 5, null).hospitalRating)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `zero stars throws (below floor)`() {
        buildRatingPatch(RatingRole.HospitalRatesEngineer, 0, null)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `six stars throws (above ceiling)`() {
        buildRatingPatch(RatingRole.HospitalRatesEngineer, 6, null)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative stars throws`() {
        buildRatingPatch(RatingRole.HospitalRatesEngineer, -1, null)
    }
}
