package com.equipseva.app.features.profile.forms

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the user-address form validator. India-only flow — the pincode
 * is exactly 6 ASCII digits (the cascading city/state picker is wired
 * to Indian states). The previous 4..10 window was too loose and let
 * international postal codes through to the AddressRepository which
 * couldn't actually deliver to them; pin the tight gate.
 */
class AddressFormValidatorTest {

    private fun form(
        fullName: String = "Ravi Kumar",
        phone: String = "+919812345678",
        line1: String = "Plot 12 Banjara Hills",
        city: String = "Hyderabad",
        state: String = "Telangana",
        pincode: String = "500034",
    ) = AddressFormViewModel.Form(
        fullName = fullName,
        phone = phone,
        line1 = line1,
        city = city,
        state = state,
        pincode = pincode,
    )

    @Test fun `happy path yields null (no error)`() {
        assertNull(validateAddressForm(form()))
    }

    // ---- required fields ----

    @Test fun `blank fullName yields required-fields error`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(fullName = "")),
        )
    }

    @Test fun `blank phone yields required-fields error`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(phone = "")),
        )
    }

    @Test fun `blank line1 yields required-fields error`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(line1 = "")),
        )
    }

    @Test fun `blank city yields required-fields error`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(city = "")),
        )
    }

    @Test fun `blank state yields required-fields error`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(state = "")),
        )
    }

    @Test fun `whitespace-only field is treated as blank`() {
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            validateAddressForm(form(fullName = "   ")),
        )
    }

    // ---- pincode ----

    @Test fun `pincode 5 digits fails the 6-digit gate`() {
        // Defense against the previous loose 4..10 window.
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(form(pincode = "50003")),
        )
    }

    @Test fun `pincode 7 digits fails the 6-digit gate`() {
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(form(pincode = "5000345")),
        )
    }

    @Test fun `pincode with non-digit chars fails`() {
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(form(pincode = "50A034")),
        )
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(form(pincode = "500 34")),  // space
        )
    }

    @Test fun `pincode with Devanagari digits fails (ASCII-only contract)`() {
        // Char.isDigit() would accept "१२३४५६" but '0'..'9' is the
        // ASCII range. Pin so a future tolerant refactor doesn't slip
        // past — international wire format would break delivery.
        assertEquals(
            "Pincode must be 6 digits.",
            validateAddressForm(form(pincode = "१२३४५६")),
        )
    }

    @Test fun `pincode exactly 6 ASCII digits passes`() {
        assertNull(validateAddressForm(form(pincode = "560001")))  // BLR
        assertNull(validateAddressForm(form(pincode = "110001")))  // DEL
    }

    @Test fun `required-fields check wins over pincode-format (single message at a time)`() {
        // When BOTH a required field is blank AND pincode is malformed,
        // the required-fields message surfaces (not pincode). Pins so
        // the user sees the most-fundamental issue first.
        val out = validateAddressForm(form(fullName = "", pincode = "12"))
        assertEquals(
            "Name, phone, line 1, city, state, pincode are required.",
            out,
        )
    }
}
