package com.equipseva.app.features.profile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the length-hint supportingText window on the Add-Phone screen.
 *
 * Window: phone length 4..10 inclusive AND no server error.
 *   - 0..3 → silent (user still typing the +91 prefix)
 *   - 4..10 → hint visible ("Enter 10 digits after +91")
 *   - >= 11 → silent (Save will fire)
 *   - hasError → silent (server error takes precedence)
 */
class AddPhoneLengthHintTest {

    @Test fun `phone length 4 surfaces hint`() {
        // Window lower bound — inclusive.
        assertEquals(
            "Enter 10 digits after +91",
            addPhoneLengthHint(hasError = false, phoneLength = 4),
        )
    }

    @Test fun `phone length 10 surfaces hint`() {
        // Window upper bound — inclusive.
        assertEquals(
            "Enter 10 digits after +91",
            addPhoneLengthHint(hasError = false, phoneLength = 10),
        )
    }

    @Test fun `phone length 3 returns null (too early)`() {
        // Pin lower bound — narrowing to 4 prevents the hint from
        // firing while user types the +91 prefix.
        assertNull(addPhoneLengthHint(hasError = false, phoneLength = 3))
    }

    @Test fun `phone length 11 returns null (Save will fire)`() {
        // Pin upper bound — once the field is routable, hint is
        // redundant.
        assertNull(addPhoneLengthHint(hasError = false, phoneLength = 11))
    }

    @Test fun `phone length 0 returns null (blank field)`() {
        // Pin — never show hint on a blank field. A widening
        // refactor to 0..10 would surface this as noise.
        assertNull(addPhoneLengthHint(hasError = false, phoneLength = 0))
    }

    @Test fun `hasError true suppresses hint regardless of length`() {
        // Critical pin — server error takes precedence in the
        // supportingText slot.
        assertNull(addPhoneLengthHint(hasError = true, phoneLength = 4))
        assertNull(addPhoneLengthHint(hasError = true, phoneLength = 7))
        assertNull(addPhoneLengthHint(hasError = true, phoneLength = 10))
    }

    @Test fun `Enter 10 digits phrasing pinned verbatim`() {
        // Pin literal — "Enter 10 digits after +91" implies the user
        // SHOULD see the +91 prefix already. A refactor to "Enter
        // your 10-digit number" would suggest the prefix is missing.
        val out = addPhoneLengthHint(hasError = false, phoneLength = 7)
        assertEquals("Enter 10 digits after +91", out)
    }
}
