package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the four pure helpers behind the AMC-visit row on the engineer
 * surface:
 *
 *   * amcVisitHospitalName — blank-to-"Hospital" fallback (no
 *     dev-placeholder strings leaking to engineers)
 *   * amcVisitStatusLabel — wire enum → human-readable pill text
 *     (first-letter-only capitalisation, matches StatusPill)
 *   * amcVisitNumberLine — "Visit #N · Equipment" composition with
 *     null-equipment fallback to "Visit #N"
 *   * amcVisitBreachCountLabel — singular/plural breach pluralisation
 *     ("1 breach" vs "N breaches")
 */
class AmcVisitRowHelpersTest {

    // ---- amcVisitHospitalName ----

    @Test fun `null hospital name collapses to generic Hospital`() {
        // The old "(unnamed hospital)" placeholder read as a
        // missing-data bug — pin the friendly fallback.
        assertEquals("Hospital", amcVisitHospitalName(null))
    }

    @Test fun `blank hospital name collapses to Hospital`() {
        assertEquals("Hospital", amcVisitHospitalName("  "))
        assertEquals("Hospital", amcVisitHospitalName(""))
    }

    @Test fun `present hospital name passes through verbatim`() {
        assertEquals("Apollo Hospitals", amcVisitHospitalName("Apollo Hospitals"))
    }

    // ---- amcVisitStatusLabel ----

    @Test fun `underscored status replaces underscores with spaces`() {
        assertEquals("In progress", amcVisitStatusLabel("in_progress"))
        assertEquals("En route", amcVisitStatusLabel("en_route"))
    }

    @Test fun `single word status capitalises first letter only`() {
        assertEquals("Completed", amcVisitStatusLabel("completed"))
        assertEquals("Assigned", amcVisitStatusLabel("assigned"))
    }

    @Test fun `only first letter capitalised (regression — no title case)`() {
        // Pin so a refactor to title-case ("In Progress") doesn't
        // drift from the rest-of-app convention. Trailing words stay
        // lowercase.
        assertEquals("In progress", amcVisitStatusLabel("in_progress"))
        assertEquals(false, amcVisitStatusLabel("in_progress").contains("In Progress"))
    }

    @Test fun `unknown wire status round-trips with first letter cap`() {
        assertEquals("Future state", amcVisitStatusLabel("future_state"))
    }

    @Test fun `blank status produces empty string`() {
        assertEquals("", amcVisitStatusLabel(""))
    }

    // ---- amcVisitNumberLine ----

    @Test fun `visit number with equipment renders both joined by middle-dot`() {
        assertEquals(
            "Visit #3 · Imaging radiology",
            amcVisitNumberLine(3, "imaging_radiology"),
        )
    }

    @Test fun `visit number with null equipment renders visit only`() {
        assertEquals("Visit #3", amcVisitNumberLine(3, null))
    }

    @Test fun `visit number with blank equipment renders visit only`() {
        // Pin so a blank server-side equipment_type doesn't surface
        // as "Visit #3 · " trailing-separator garbage.
        assertEquals("Visit #3", amcVisitNumberLine(3, ""))
        assertEquals("Visit #3", amcVisitNumberLine(3, "   "))
    }

    @Test fun `visit number 1 renders without special-case copy`() {
        assertEquals("Visit #1", amcVisitNumberLine(1, null))
    }

    @Test fun `large visit number passes through`() {
        assertEquals("Visit #42", amcVisitNumberLine(42, null))
    }

    // ---- amcVisitBreachCountLabel ----

    @Test fun `1 breach uses singular (no es suffix)`() {
        // Pin the singular case — a regression to always "es" would
        // surface "1 open SLA breaches" on the most common
        // single-breach case.
        assertEquals("1 open SLA breach", amcVisitBreachCountLabel(1))
    }

    @Test fun `2 breaches uses plural`() {
        assertEquals("2 open SLA breaches", amcVisitBreachCountLabel(2))
    }

    @Test fun `5 breaches uses plural`() {
        assertEquals("5 open SLA breaches", amcVisitBreachCountLabel(5))
    }

    @Test fun `zero breaches still pluralises (caller gates on positive count)`() {
        // The screen gates on breachCount > 0 before showing the
        // pill, but pin a sensible fallback so the helper is total.
        assertEquals("0 open SLA breaches", amcVisitBreachCountLabel(0))
    }
}
