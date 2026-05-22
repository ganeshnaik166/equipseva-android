package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the engineer-feed empty-state copy split. Critical regression:
 * the old "No jobs in this radius / Try widening" copy lied when the
 * user already had All radii selected — there's no wider option,
 * and the count reflects every open job in the country.
 *
 * Pin the two branches so:
 *   * All-radius → "No open jobs right now" + pull-to-refresh nudge
 *   * Numeric radius → "No jobs in this radius" + widen suggestion
 */
class EmptyFeedStateCopyTest {

    @Test fun `null radius (All) uses no-open-jobs title and PTR subtitle`() {
        val copy = emptyFeedStateCopy(null)
        assertEquals("No open jobs right now", copy.title)
        assertEquals(
            "Pull to refresh — new requests show up the moment hospitals post.",
            copy.subtitle,
        )
    }

    @Test fun `numeric radius uses in-this-radius title and widen-radius subtitle`() {
        val copy = emptyFeedStateCopy(50)
        assertEquals("No jobs in this radius", copy.title)
        assertEquals(
            "Try widening the radius filter, or pick All to see every open job.",
            copy.subtitle,
        )
    }

    @Test fun `All-radius subtitle does NOT suggest widening (regression — there is no wider)`() {
        val copy = emptyFeedStateCopy(null)
        // Critical pin — old version surfaced "Try widening" even
        // when the user was on All. Pin so a refactor that collapsed
        // the two branches doesn't resurrect that lie.
        assertEquals(false, copy.subtitle.contains("widen", ignoreCase = true))
    }

    @Test fun `numeric radius subtitle suggests widening or picking All`() {
        val copy = emptyFeedStateCopy(25)
        // The widen / All-pick affordance is the user's only
        // recovery path — pin so the helper text stays actionable.
        val mentionsRecovery = copy.subtitle.contains("widen", ignoreCase = true) ||
            copy.subtitle.contains("All", ignoreCase = true)
        assertEquals(true, mentionsRecovery)
    }

    @Test fun `radius value does not appear verbatim in copy`() {
        // The numeric radius is already shown in the StatStrip and
        // the filter chip — the empty-state copy stays generic so
        // adding a new radius value doesn't require re-localising
        // this string.
        val copy = emptyFeedStateCopy(50)
        assertEquals(false, copy.title.contains("50"))
        assertEquals(false, copy.subtitle.contains("50"))
    }

    @Test fun `all-radius vs numeric branches produce distinct copy`() {
        val all = emptyFeedStateCopy(null)
        val numeric = emptyFeedStateCopy(50)
        assertEquals(true, all.title != numeric.title)
        assertEquals(true, all.subtitle != numeric.subtitle)
    }
}
