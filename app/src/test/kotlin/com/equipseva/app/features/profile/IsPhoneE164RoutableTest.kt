package com.equipseva.app.features.profile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the AddPhone form's E.164 routability gate. Two regions worth
 * defending:
 *
 *   1) The '+' prefix is required. Without it, the server can't
 *      disambiguate national vs international format and SMS / call
 *      dispatch silently picks the wrong country code.
 *   2) The 11-char floor catches "+12345678" (9 chars), which was
 *      accepted by the previous '< 10' floor and silently routed
 *      messages to a wrong number on carriers that strip a leading
 *      country code. India ('+91' + 10 digits = 13 chars) is the
 *      reference happy path.
 */
class IsPhoneE164RoutableTest {

    @Test fun `Indian +91 number with 10 digits routes`() {
        assertTrue(isPhoneE164Routable("+919999999999"))
    }

    @Test fun `number without leading plus is rejected`() {
        // Critical — server-side dispatch can't disambiguate without
        // the '+' prefix. Pin so a future tolerant strip doesn't slip.
        assertFalse(isPhoneE164Routable("919999999999"))
        assertFalse(isPhoneE164Routable("9999999999"))
    }

    @Test fun `9-char number (one below floor) is rejected`() {
        // "+12345678" was the silent-failure case before the 11-char
        // floor landed. Pin so a future "relax to 10" change is
        // intentional.
        assertFalse(isPhoneE164Routable("+12345678"))
    }

    @Test fun `exactly 11 chars at the floor is accepted`() {
        // The floor is inclusive — pin so a "> vs >=" off-by-one
        // surfaces.
        assertTrue(isPhoneE164Routable("+1234567890"))
    }

    @Test fun `10-char number is rejected (just below floor)`() {
        assertFalse(isPhoneE164Routable("+123456789"))
    }

    @Test fun `bare plus is rejected (initial UI state)`() {
        // AddPhone form initialises the field with "+91" — the user
        // hasn't typed yet, so the empty-prefix shape must be
        // disabled.
        assertFalse(isPhoneE164Routable("+"))
        assertFalse(isPhoneE164Routable("+91"))
    }

    @Test fun `empty input is rejected`() {
        assertFalse(isPhoneE164Routable(""))
    }

    @Test fun `non-digit chars are NOT a gate (caller is expected to normalise first)`() {
        // The gate only checks prefix + length, not character class.
        // Caller runs normalizeIndiaMobileInput first to strip
        // non-digits. Pin so the responsibility split stays clear.
        assertTrue(isPhoneE164Routable("+91-9999-9999"))
    }

    @Test fun `oversized E164-like input still passes (server-side decides too-long)`() {
        // E.164 spec caps at 15 digits of national number; client
        // gate doesn't enforce that — server-side dispatch rejects
        // oversized values with a friendlier error.
        assertTrue(isPhoneE164Routable("+9199999999999999999"))
    }
}
