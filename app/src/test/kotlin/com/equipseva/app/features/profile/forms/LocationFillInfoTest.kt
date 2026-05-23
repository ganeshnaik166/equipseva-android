package com.equipseva.app.features.profile.forms

import com.equipseva.app.core.location.LocationFetcher
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the location-pin transient feedback resolver. Three-way
 * precedence:
 *
 *   1) Filled at least one previously-blank field → list them.
 *   2) Geocoder returned something but every field was already typed
 *      → "Saved your GPS pin — fill the address fields manually."
 *   3) Geocoder returned nothing → "Saved your GPS pin (couldn't read
 *      a street address here)."
 *
 * The "only fill BLANK fields" semantics is critical: a user who
 * already typed their landmark / line2 must NOT see those overwritten
 * by the geocoder. Pinned so a future "freshness-first" refactor
 * surfaces.
 */
class LocationFillInfoTest {

    private val emptyForm = AddressFormViewModel.Form()
    private val coords = LocationFetcher.Coords(lat = 17.4, lng = 78.4)

    private fun resolved(
        line1: String? = null,
        city: String? = null,
        state: String? = null,
        pincode: String? = null,
    ) = LocationFetcher.Resolved(
        coords = coords,
        line1 = line1,
        city = city,
        state = state,
        pincode = pincode,
    )

    @Test fun `geocoder fills line1 city state pincode on empty form`() {
        val info = locationFillInfo(
            current = emptyForm,
            resolved = resolved(
                line1 = "Plot 12",
                city = "Hyderabad",
                state = "Telangana",
                pincode = "500034",
            ),
        )
        assertEquals(
            "Filled line 1, city, state, pincode from your GPS pin.",
            info,
        )
    }

    @Test fun `only fills BLANK fields - user-typed line1 is preserved in the copy`() {
        // If the user already typed line1, that field is NOT in the
        // filled list — pin the blank-only contract.
        val info = locationFillInfo(
            current = emptyForm.copy(line1 = "User-typed line 1"),
            resolved = resolved(
                line1 = "Geocoder line 1",
                city = "Hyderabad",
                state = "Telangana",
                pincode = "500034",
            ),
        )
        assertEquals(
            "Filled city, state, pincode from your GPS pin.",
            info,
        )
    }

    @Test fun `geocoder returns null fields - falls back to 'manual fill' copy`() {
        // Geocoder ran and returned a Resolved object but every field
        // is null (rural area, no street address). Fall back to copy
        // (2).
        val info = locationFillInfo(
            current = emptyForm,
            resolved = resolved(),  // every field null
        )
        assertEquals(
            "Saved your GPS pin — fill the address fields manually.",
            info,
        )
    }

    @Test fun `geocoder returns null entirely - falls back to copy (3)`() {
        // The geocoder threw / no network — `resolved` is null. Copy (3)
        // surfaces so the user knows the pin still landed.
        val info = locationFillInfo(current = emptyForm, resolved = null)
        assertEquals(
            "Saved your GPS pin (couldn't read a street address here).",
            info,
        )
    }

    @Test fun `geocoder filled everything but user already typed every field`() {
        // Every form field is pre-filled by the user; geocoder also
        // has values. No "filled" message — fall to copy (2).
        val current = emptyForm.copy(
            line1 = "Mine",
            city = "Mine",
            state = "Mine",
            pincode = "500034",
        )
        val info = locationFillInfo(
            current = current,
            resolved = resolved(
                line1 = "Geo",
                city = "Geo",
                state = "Geo",
                pincode = "560001",
            ),
        )
        assertEquals(
            "Saved your GPS pin — fill the address fields manually.",
            info,
        )
    }

    @Test fun `blank string in resolved field doesn't count as a fill`() {
        // resolved.line1 = " " (whitespace-only) treated as null —
        // pin the isNullOrBlank gate so an empty string from the
        // geocoder doesn't surface as "Filled line 1" with empty text.
        val info = locationFillInfo(
            current = emptyForm,
            resolved = resolved(line1 = "  ", city = "Hyderabad"),
        )
        assertEquals(
            "Filled city from your GPS pin.",
            info,
        )
    }

    @Test fun `single field filled - singular list copy`() {
        val info = locationFillInfo(
            current = emptyForm,
            resolved = resolved(city = "Hyderabad"),
        )
        assertEquals(
            "Filled city from your GPS pin.",
            info,
        )
    }

    @Test fun `pincode field works the same way`() {
        val info = locationFillInfo(
            current = emptyForm.copy(pincode = "560001"),  // user-typed
            resolved = resolved(pincode = "500034"),
        )
        // User-typed pincode preserved → no "filled" entry → falls
        // through to copy (2).
        assertEquals(
            "Saved your GPS pin — fill the address fields manually.",
            info,
        )
    }
}
