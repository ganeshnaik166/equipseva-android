package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the KYC service-area cascade used by EngineerProfileViewModel +
 * AddressForm. The state list shape (28 states + 8 UTs = 36 entries),
 * the district cascade lookup, and the legacy `compose(...)` joiner all
 * have UX consequences if they regress — for example, a stray comma in
 * the composed city string is what backend RLS uses as the city facet
 * for the engineer directory filter.
 *
 * No mocks — `IndiaLocations` is a pure data object with three lookup
 * helpers (`districtsFor`, `mandalsFor`, `compose`). Plain JUnit only.
 */
class IndiaLocationsTest {

    // --- STATES list shape -------------------------------------------------

    @Test fun `STATES contains all 28 states plus 8 union territories`() {
        // Total = 36. If the count drifts (e.g. a new UT carved out), the
        // picker UI's dropdown height needs revisiting.
        assertEquals(36, IndiaLocations.STATES.size)
    }

    @Test fun `STATES list is unique`() {
        // No accidental duplicate entries — would surface as a duplicate
        // dropdown row.
        assertEquals(IndiaLocations.STATES.size, IndiaLocations.STATES.toSet().size)
    }

    @Test fun `STATES contains active-market states`() {
        // Telangana is the launch market; Karnataka + Maharashtra + Andhra
        // are adjacent rollout regions. These four must stay present.
        assertTrue(IndiaLocations.STATES.contains("Telangana"))
        assertTrue(IndiaLocations.STATES.contains("Karnataka"))
        assertTrue(IndiaLocations.STATES.contains("Maharashtra"))
        assertTrue(IndiaLocations.STATES.contains("Andhra Pradesh"))
    }

    @Test fun `COUNTRY constant is India`() {
        // The picker fixes country to India — backend assumes this when
        // persisting `engineers.country` so don't surprise it.
        assertEquals("India", IndiaLocations.COUNTRY)
    }

    // --- districtsFor ------------------------------------------------------

    @Test fun `districtsFor known state returns non-empty list`() {
        // Telangana has 33 districts as of LGD 2024.
        val districts = IndiaLocations.districtsFor("Telangana")
        assertTrue("expected Telangana districts, got empty", districts.isNotEmpty())
        assertTrue(districts.contains("Hyderabad"))
        assertTrue(districts.contains("Rangareddy"))
    }

    @Test fun `districtsFor unknown state returns empty list`() {
        // Unknown state → empty list so the UI shows the free-text District
        // input fallback. Must not throw.
        assertEquals(emptyList<String>(), IndiaLocations.districtsFor("Atlantis"))
    }

    @Test fun `districtsFor null or blank state returns empty list`() {
        // Initial picker state before user selects a state — must not NPE.
        assertEquals(emptyList<String>(), IndiaLocations.districtsFor(null))
        assertEquals(emptyList<String>(), IndiaLocations.districtsFor(""))
    }

    @Test fun `districtsFor single-district state Goa returns both`() {
        // Goa has exactly North + South. Spot-check ordering matches data.
        assertEquals(listOf("North Goa", "South Goa"), IndiaLocations.districtsFor("Goa"))
    }

    @Test fun `districtsFor union territory Chandigarh returns itself`() {
        // Chandigarh is a single-district UT — the district list is just
        // the UT name itself so the picker still shows a valid choice.
        assertEquals(listOf("Chandigarh"), IndiaLocations.districtsFor("Chandigarh"))
    }

    // --- mandalsFor --------------------------------------------------------

    @Test fun `mandalsFor known Telangana district returns mandal list`() {
        // Hyderabad has 15+ mandals; Ameerpet is the canonical example
        // because most service activity in v1 happens there.
        val mandals = IndiaLocations.mandalsFor("Telangana", "Hyderabad")
        assertTrue("expected Hyderabad mandals", mandals.isNotEmpty())
        assertTrue(mandals.contains("Ameerpet"))
        assertTrue(mandals.contains("Secunderabad"))
    }

    @Test fun `mandalsFor non-Telangana state returns empty list`() {
        // Only Telangana has mandal data; other states return empty so
        // the UI hides the Mandal step entirely.
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("Karnataka", "Bengaluru Urban"))
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("Maharashtra", "Pune"))
    }

    @Test fun `mandalsFor null or blank state or district returns empty list`() {
        // Defensive — picker calls this on every recomposition so a stale
        // null state must not throw.
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor(null, "Hyderabad"))
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("Telangana", null))
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("", "Hyderabad"))
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("Telangana", ""))
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("   ", "Hyderabad"))
    }

    @Test fun `mandalsFor unknown Telangana district returns empty list`() {
        // Mandal map keyed by "state|district" — a typoed district must
        // return empty, not crash.
        assertEquals(emptyList<String>(), IndiaLocations.mandalsFor("Telangana", "Atlantis"))
    }

    // --- compose -----------------------------------------------------------

    @Test fun `compose joins mandal district state with comma-space`() {
        // This is the exact format the backend stores in engineers.city.
        // Order is mandal → district → state (most specific first) which
        // matches what Google Maps geocoding returns.
        assertEquals(
            "Ameerpet, Hyderabad, Telangana",
            IndiaLocations.compose("Telangana", "Hyderabad", "Ameerpet"),
        )
    }

    @Test fun `compose drops null parts so no leading or trailing comma`() {
        // Mandal optional in non-Telangana states — must not render
        // "Pune, Maharashtra" with a leading ", ".
        assertEquals(
            "Pune, Maharashtra",
            IndiaLocations.compose("Maharashtra", "Pune", null),
        )
        assertEquals(
            "Maharashtra",
            IndiaLocations.compose("Maharashtra", null, null),
        )
    }

    @Test fun `compose drops blank parts`() {
        // Empty strings from cleared form fields must collapse the same
        // way as nulls — avoids ", , Telangana" garbage in the city facet.
        assertEquals(
            "Telangana",
            IndiaLocations.compose("Telangana", "", "   "),
        )
        assertEquals(
            "Hyderabad, Telangana",
            IndiaLocations.compose("Telangana", "Hyderabad", ""),
        )
    }

    @Test fun `compose all null returns empty string`() {
        // Brand-new form with nothing picked yet — returns "" so the
        // UI's "Service area" placeholder still shows.
        assertEquals("", IndiaLocations.compose(null, null, null))
        assertEquals("", IndiaLocations.compose("", "", ""))
    }

    // --- coverage consistency ---------------------------------------------

    @Test fun `every STATES entry has a districts entry that is non-null`() {
        // districtsFor never throws on a valid state — even if the data
        // map omits an entry, .orEmpty() should kick in. This pins the
        // contract so a future refactor doesn't accidentally return null.
        IndiaLocations.STATES.forEach { state ->
            assertNotNull("districtsFor($state) returned null", IndiaLocations.districtsFor(state))
        }
    }

    @Test fun `Telangana districts list has no duplicates`() {
        // Hand-curated lists are prone to dupes when merging PRs. Pin so
        // the dropdown doesn't show "Hyderabad" twice.
        val districts = IndiaLocations.districtsFor("Telangana")
        assertEquals(districts.size, districts.toSet().size)
        assertFalse(districts.isEmpty())
    }
}
