package com.equipseva.app.features.profile.forms

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the pure derivations under AddressFormViewModel / AddressFormScreen:
 *  - validateAddressForm: VM.save server-side guard
 *  - canSaveAddressForm: looser UI-side gate for the Save button
 *  - locationFillInfo: feedback string after "Use my current location"
 *  - fillIfBlank: never-overwrite helper that respects user-typed values
 *
 * The 6-digit pincode check used to be 4..10 (PR pre-#142) which let
 * international formats through to a delivery flow that only supports
 * India. These tests keep that tightening pinned.
 */
class AddressFormHelpersTest {

    private fun validForm() = AddressFormViewModel.Form(
        fullName = "Ganesh Dhanavath",
        phone = "9876543210",
        line1 = "1 Main Rd",
        city = "Bangalore",
        state = "Karnataka",
        pincode = "560001",
    )

    /* --------- validateAddressForm (server-side guard) --------- */

    @Test fun `validateAddressForm returns null for a complete form`() {
        assertNull(validateAddressForm(validForm()))
    }

    @Test fun `validateAddressForm flags any blank required field`() {
        val msg = "Name, phone, line 1, city, state, pincode are required."
        assertEquals(msg, validateAddressForm(validForm().copy(fullName = "")))
        assertEquals(msg, validateAddressForm(validForm().copy(phone = "")))
        assertEquals(msg, validateAddressForm(validForm().copy(line1 = "")))
        assertEquals(msg, validateAddressForm(validForm().copy(city = "")))
        assertEquals(msg, validateAddressForm(validForm().copy(state = "")))
        assertEquals(msg, validateAddressForm(validForm().copy(pincode = "")))
    }

    @Test fun `validateAddressForm treats whitespace-only as blank`() {
        // String.isBlank() is what production calls — pin it so a future
        // refactor to isEmpty() doesn't let " " through.
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(validForm().copy(fullName = "   ")),
        )
    }

    @Test fun `validateAddressForm rejects a non-6-digit pincode`() {
        val msg = "Pincode must be 6 digits."
        assertEquals(msg, validateAddressForm(validForm().copy(pincode = "12345")))
        assertEquals(msg, validateAddressForm(validForm().copy(pincode = "1234567")))
    }

    @Test fun `validateAddressForm rejects a 6-char pincode containing letters`() {
        // Old 4..10 window passed "560A01"; the 6-digit + all-digit guard
        // is what blocks it. Both branches matter.
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(validForm().copy(pincode = "560A01")),
        )
    }

    @Test fun `validateAddressForm accepts the minimum-valid Indian pincode`() {
        // 110001 is Delhi's GPO — real-world smoke value.
        assertNull(validateAddressForm(validForm().copy(pincode = "110001")))
    }

    /* --------- canSaveAddressForm (UI gate) --------- */

    @Test fun `canSaveAddressForm true for a fully-typed form`() {
        assertTrue(canSaveAddressForm(validForm()))
    }

    @Test fun `canSaveAddressForm false on any blank required field`() {
        assertFalse(canSaveAddressForm(validForm().copy(fullName = "")))
        assertFalse(canSaveAddressForm(validForm().copy(phone = "")))
        assertFalse(canSaveAddressForm(validForm().copy(line1 = "")))
        assertFalse(canSaveAddressForm(validForm().copy(city = "")))
        assertFalse(canSaveAddressForm(validForm().copy(state = "")))
    }

    @Test fun `canSaveAddressForm uses a looser 4 to 10 char pincode window`() {
        // The UI gate is intentionally permissive so the button enables
        // as the user is still typing; the strict 6-digit check in
        // validateAddressForm still blocks submit.
        assertTrue(canSaveAddressForm(validForm().copy(pincode = "5600")))
        assertTrue(canSaveAddressForm(validForm().copy(pincode = "5600012345")))
        assertFalse(canSaveAddressForm(validForm().copy(pincode = "560")))
        assertFalse(canSaveAddressForm(validForm().copy(pincode = "56000123456")))
    }

    /* --------- locationFillInfo --------- */

    @Test fun `locationFillInfo lists every field the geocoder actually filled`() {
        val info = locationFillInfo(
            line1Blank = true, cityBlank = true, stateBlank = true, pincodeBlank = true,
            resolvedLine1 = "1 Main Rd", resolvedCity = "Bangalore",
            resolvedState = "Karnataka", resolvedPincode = "560001",
            resolvedAny = true,
        )
        assertEquals("Filled line 1, city, state, pincode from your GPS pin.", info)
    }

    @Test fun `locationFillInfo skips fields the user already typed`() {
        val info = locationFillInfo(
            line1Blank = false, cityBlank = true, stateBlank = false, pincodeBlank = true,
            resolvedLine1 = "1 Main Rd", resolvedCity = "Bangalore",
            resolvedState = "Karnataka", resolvedPincode = "560001",
            resolvedAny = true,
        )
        assertEquals("Filled city, pincode from your GPS pin.", info)
    }

    @Test fun `locationFillInfo geocoder hit but every field already typed`() {
        val info = locationFillInfo(
            line1Blank = false, cityBlank = false, stateBlank = false, pincodeBlank = false,
            resolvedLine1 = "1 Main Rd", resolvedCity = "Bangalore",
            resolvedState = "Karnataka", resolvedPincode = "560001",
            resolvedAny = true,
        )
        assertEquals(
            "Saved your GPS pin — fill the address fields manually.",
            info,
        )
    }

    @Test fun `locationFillInfo geocoder returned nothing`() {
        val info = locationFillInfo(
            line1Blank = true, cityBlank = true, stateBlank = true, pincodeBlank = true,
            resolvedLine1 = null, resolvedCity = null,
            resolvedState = null, resolvedPincode = null,
            resolvedAny = false,
        )
        assertEquals(
            "Saved your GPS pin (couldn't read a street address here).",
            info,
        )
    }

    @Test fun `locationFillInfo treats blank resolved values as missing`() {
        val info = locationFillInfo(
            line1Blank = true, cityBlank = true, stateBlank = true, pincodeBlank = true,
            resolvedLine1 = "  ", resolvedCity = "",
            resolvedState = null, resolvedPincode = "",
            resolvedAny = true,
        )
        assertEquals(
            "Saved your GPS pin — fill the address fields manually.",
            info,
        )
    }

    /* --------- fillIfBlank --------- */

    @Test fun `fillIfBlank keeps the user value when present`() {
        assertEquals("Typed", fillIfBlank("Typed", "GeoResolved"))
        assertEquals("Typed", fillIfBlank("Typed", null))
    }

    @Test fun `fillIfBlank takes the resolved value when current is blank`() {
        assertEquals("GeoResolved", fillIfBlank("", "GeoResolved"))
        assertEquals("GeoResolved", fillIfBlank("   ", "GeoResolved"))
    }

    @Test fun `fillIfBlank keeps the blank when resolved is also blank or null`() {
        assertEquals("", fillIfBlank("", null))
        assertEquals("   ", fillIfBlank("   ", "   "))
        assertEquals("", fillIfBlank("", ""))
    }
}
