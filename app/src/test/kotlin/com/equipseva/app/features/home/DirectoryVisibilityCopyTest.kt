package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the home-screen directory-visibility banner copy + the gate
 * enum's `isHidden` semantic. The banner only renders for engineers
 * whose KYC has cleared but who are still filtered out of the hospital
 * directory by the client-side `isBookable` predicate (missing
 * `hourly_rate` or empty `specializations`). The copy below is the
 * engineer's first signal that they're invisible — a regression that
 * swapped or null-collapsed the variants would either re-introduce the
 * silent-failure bug or nag verified engineers who are already shown.
 */
class DirectoryVisibilityCopyTest {

    @Test fun `MissingBoth shows the most explicit invisible-yet copy`() {
        val copy = directoryVisibilityCopy(HomeHubViewModel.DirectoryGate.MissingBoth)
        assertNotNull(copy)
        assertEquals("You're not visible to hospitals yet", copy?.first)
        assertTrue(
            "subtitle should mention BOTH rate AND specialization",
            copy?.second?.contains("hourly rate", ignoreCase = true) == true &&
                copy.second.contains("specialization", ignoreCase = true),
        )
    }

    @Test fun `MissingRate copy points at the rate only`() {
        val copy = directoryVisibilityCopy(HomeHubViewModel.DirectoryGate.MissingRate)
        assertNotNull(copy)
        assertEquals("Add your hourly rate to start getting bookings", copy?.first)
        assertTrue(
            "subtitle should mention rate but not specialization",
            copy?.second?.contains("rate", ignoreCase = true) == true,
        )
        assertFalse(
            "MissingRate copy must not mention specialization (already set)",
            copy?.second?.contains("specialization", ignoreCase = true) == true,
        )
    }

    @Test fun `MissingSpecs copy points at the specialization only`() {
        val copy = directoryVisibilityCopy(HomeHubViewModel.DirectoryGate.MissingSpecs)
        assertNotNull(copy)
        assertEquals("Pick at least one specialization", copy?.first)
        assertTrue(
            "subtitle should mention specialization / equipment type",
            copy?.second?.contains("specialization", ignoreCase = true) == true ||
                copy?.second?.contains("equipment", ignoreCase = true) == true,
        )
        assertFalse(
            "MissingSpecs copy must not mention rate (already set)",
            copy?.second?.contains("rate", ignoreCase = true) == true,
        )
    }

    @Test fun `Visible returns null so no banner renders`() {
        assertNull(directoryVisibilityCopy(HomeHubViewModel.DirectoryGate.Visible))
    }

    @Test fun `Unknown returns null so no banner flashes during initial load`() {
        // Unknown is the seed state before the engineer row resolves; if
        // it accidentally rendered a banner the engineer would see a
        // false-alarm "you're hidden" message every cold start.
        assertNull(directoryVisibilityCopy(HomeHubViewModel.DirectoryGate.Unknown))
    }

    @Test fun `isHidden matches the three problem states only`() {
        assertTrue(HomeHubViewModel.DirectoryGate.MissingBoth.isHidden)
        assertTrue(HomeHubViewModel.DirectoryGate.MissingRate.isHidden)
        assertTrue(HomeHubViewModel.DirectoryGate.MissingSpecs.isHidden)
        assertFalse(HomeHubViewModel.DirectoryGate.Visible.isHidden)
        assertFalse(
            "Unknown must NOT be hidden — otherwise the banner flashes before profile resolves",
            HomeHubViewModel.DirectoryGate.Unknown.isHidden,
        )
    }

    @Test fun `each visible state produces a distinct title (no silent collapse)`() {
        val titles = HomeHubViewModel.DirectoryGate.values()
            .mapNotNull { directoryVisibilityCopy(it)?.first }
            .toSet()
        // MissingRate, MissingSpecs, MissingBoth → 3 distinct titles.
        // If two enum branches ever collapse to the same copy a refactor
        // probably went wrong; pin so it surfaces in review.
        assertEquals(3, titles.size)
    }

    @Test fun `every rendered subtitle suggests a concrete next step`() {
        val actionableWords = listOf("add", "pick", "set", "select", "save")
        HomeHubViewModel.DirectoryGate.values()
            .mapNotNull { directoryVisibilityCopy(it)?.second }
            .forEach { subtitle ->
                val hasAction = actionableWords.any { subtitle.contains(it, ignoreCase = true) }
                assertTrue(
                    "subtitle should suggest an action: '$subtitle'",
                    hasAction,
                )
            }
    }
}
