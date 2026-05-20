package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.location.IndiaLocations
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the pure parsers extracted out of [KycViewModel.hydrate] +
 * [KycViewModel.onServiceCoordsChange]. These look harmless but were
 * silently dropping district pre-selects when the geocoder labelled
 * states with " State" suffixes — that bug shipped twice in v0.x, hence
 * the branch coverage.
 */
class KycHydrateHelpersTest {

    /* --------- parseStateDistrict (engineer.city → cascade dropdowns) --------- */

    @Test fun `parseStateDistrict resolves a comma-separated district + state`() {
        // Use a real (state, district) pair from IndiaLocations so the lookup
        // succeeds — synthetic strings would just return nulls.
        val state = IndiaLocations.STATES.first()
        val district = IndiaLocations.districtsFor(state).first()
        val (parsedState, parsedDistrict) = parseStateDistrict("$district, $state")
        assertEquals(state, parsedState)
        assertEquals(district, parsedDistrict)
    }

    @Test fun `parseStateDistrict handles a single-segment value as state-only`() {
        val state = IndiaLocations.STATES.first()
        val (parsedState, parsedDistrict) = parseStateDistrict(state)
        assertEquals(state, parsedState)
        // No prior segment to read as a district.
        assertNull(parsedDistrict)
    }

    @Test fun `parseStateDistrict returns nulls when the trailing segment isn't a known state`() {
        val (parsedState, parsedDistrict) = parseStateDistrict("Some city, Atlantis")
        assertNull(parsedState)
        assertNull(parsedDistrict)
    }

    @Test fun `parseStateDistrict returns null district when the prior segment isn't in the state's district list`() {
        val state = IndiaLocations.STATES.first()
        val (parsedState, parsedDistrict) = parseStateDistrict("NotARealDistrict, $state")
        assertEquals(state, parsedState)
        assertNull(parsedDistrict)
    }

    @Test fun `parseStateDistrict tolerates extra whitespace around the comma`() {
        val state = IndiaLocations.STATES.first()
        val district = IndiaLocations.districtsFor(state).first()
        val (parsedState, parsedDistrict) =
            parseStateDistrict("   $district   ,    $state   ")
        assertEquals(state, parsedState)
        assertEquals(district, parsedDistrict)
    }

    @Test fun `parseStateDistrict returns nulls for an empty string`() {
        // Empty string → split returns [""] → "" not in STATES → null/null.
        val (parsedState, parsedDistrict) = parseStateDistrict("")
        assertNull(parsedState)
        assertNull(parsedDistrict)
    }

    /* --------- matchStateFromGeocode (Geocoder label → canonical state) --------- */

    @Test fun `matchStateFromGeocode returns null for null and blank inputs`() {
        assertNull(matchStateFromGeocode(null))
        assertNull(matchStateFromGeocode(""))
        assertNull(matchStateFromGeocode("   "))
    }

    @Test fun `matchStateFromGeocode resolves an exact case-insensitive match`() {
        val canonical = IndiaLocations.STATES.first()
        assertEquals(canonical, matchStateFromGeocode(canonical.lowercase()))
    }

    @Test fun `matchStateFromGeocode resolves a geocoder suffix like " State"`() {
        // Reproduces the real-world bug — Telangana / Karnataka have been
        // observed as "Telangana State" / "Karnataka State" from Geocoder.
        val canonical = IndiaLocations.STATES.first()
        assertEquals(canonical, matchStateFromGeocode("$canonical State"))
    }

    @Test fun `matchStateFromGeocode returns null when nothing in the list matches`() {
        assertNull(matchStateFromGeocode("Atlantis"))
    }

    /* --------- matchDistrictFromGeocode --------- */

    @Test fun `matchDistrictFromGeocode returns null when state is missing`() {
        assertNull(matchDistrictFromGeocode(null, "Bangalore"))
        assertNull(matchDistrictFromGeocode("", "Bangalore"))
    }

    @Test fun `matchDistrictFromGeocode returns null when district is missing`() {
        val state = IndiaLocations.STATES.first()
        assertNull(matchDistrictFromGeocode(state, null))
        assertNull(matchDistrictFromGeocode(state, "  "))
    }

    @Test fun `matchDistrictFromGeocode resolves an exact case-insensitive match`() {
        val state = IndiaLocations.STATES.first()
        val district = IndiaLocations.districtsFor(state).first()
        assertEquals(district, matchDistrictFromGeocode(state, district.uppercase()))
    }

    @Test fun `matchDistrictFromGeocode tolerates "X District" suffixes`() {
        val state = IndiaLocations.STATES.first()
        val district = IndiaLocations.districtsFor(state).first()
        // Geocoder occasionally adds " District" / "Urban".
        val resolved = matchDistrictFromGeocode(state, "$district District")
        assertEquals(district, resolved)
    }

    @Test fun `matchDistrictFromGeocode returns null when no district fuzzy-matches`() {
        val state = IndiaLocations.STATES.first()
        assertNull(matchDistrictFromGeocode(state, "Definitely not a district name"))
    }

    @Test fun `matchDistrictFromGeocode picks one of the known districts`() {
        // Pin that the returned value is at least a member of the canonical
        // list — never invents a district. Useful sanity guard for any
        // future "smarter" fuzzy match that could hallucinate.
        val state = IndiaLocations.STATES.first()
        val district = IndiaLocations.districtsFor(state).first()
        val resolved = matchDistrictFromGeocode(state, district)
        assertTrue(resolved in IndiaLocations.districtsFor(state))
    }
}
