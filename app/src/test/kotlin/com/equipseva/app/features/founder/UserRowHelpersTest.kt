package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the five pure helpers behind the founder Users row.
 *
 * Critical cross-surface invariant: userRowContactLine is LOWERCASE
 * "no contact" while the sibling buyerKycContactLine is UPPERCASE
 * "No contact" — pin both so a refactor that unified them surfaces
 * here as a deliberate change rather than slipping in.
 */
class UserRowHelpersTest {

    // ---- userAvatarInitial -------------------------------------------

    @Test fun `first char of fullName wins, uppercased`() {
        assertEquals("A", userAvatarInitial("asha rao", "asha@x.com"))
    }

    @Test fun `null fullName falls back to first char of email, uppercased`() {
        assertEquals("F", userAvatarInitial(null, "founder@x.com"))
    }

    @Test fun `null fullName + null email surfaces question mark`() {
        // Critical pin — never a blank circle. The "?" gives the
        // founder a tap target on a fully-empty backfill row.
        assertEquals("?", userAvatarInitial(null, null))
    }

    @Test fun `empty fullName falls through to email (firstOrNull on empty is null)`() {
        // firstOrNull on "" returns null → falls through to email.
        // Pin so a refactor to first() (which would throw) surfaces.
        assertEquals("F", userAvatarInitial("", "founder@x.com"))
    }

    @Test fun `already-uppercase letter is left as-is`() {
        assertEquals("Z", userAvatarInitial("Zara", null))
    }

    @Test fun `digit first-char stays as a digit (uppercaseChar is no-op)`() {
        // Pin behaviour — digits don't have an uppercase form.
        assertEquals("9", userAvatarInitial("9to5", null))
    }

    // ---- userDisplayName ---------------------------------------------

    @Test fun `non-blank fullName wins the chain`() {
        assertEquals(
            "Asha Rao",
            userDisplayName("Asha Rao", "asha@x.com", "+91 1", "uid-abcdefghij"),
        )
    }

    @Test fun `blank fullName falls through to email`() {
        assertEquals(
            "asha@x.com",
            userDisplayName("   ", "asha@x.com", "+91 1", "uid-abcdefghij"),
        )
    }

    @Test fun `null fullName and null email fall through to phone`() {
        assertEquals(
            "+91 98765",
            userDisplayName(null, null, "+91 98765", "uid-abcdefghij"),
        )
    }

    @Test fun `all-null contact info falls through to User plus 8-char userId prefix`() {
        // Critical pin — take(8), not take(6) or take(10).
        assertEquals(
            "User · uid-abcd",
            userDisplayName(null, null, null, "uid-abcdefghij"),
        )
    }

    @Test fun `synthetic display uses U+00B7 middle dot`() {
        val name = userDisplayName(null, null, null, "uid-12345678ab")
        assertTrue(name.contains('·'))
    }

    @Test fun `short userId is left intact under the synthetic branch`() {
        // take(8) on a shorter string returns the original.
        assertEquals("User · uid", userDisplayName(null, null, null, "uid"))
    }

    @Test fun `empty email is taken verbatim, not folded`() {
        // Pin exact null gate — refactor to isNullOrBlank would skip
        // an empty email and surface phone or synthetic.
        assertEquals("", userDisplayName(null, "", "+91 1", "uid-abcdefghij"))
    }

    // ---- userRowContactLine ------------------------------------------

    @Test fun `both contacts join with middle dot`() {
        assertEquals(
            "asha@x.com · +91 1",
            userRowContactLine("asha@x.com", "+91 1"),
        )
    }

    @Test fun `null email leaves phone alone`() {
        assertEquals("+91 1", userRowContactLine(null, "+91 1"))
    }

    @Test fun `null phone leaves email alone`() {
        assertEquals("asha@x.com", userRowContactLine("asha@x.com", null))
    }

    @Test fun `both null falls back to LOWERCASE no contact`() {
        // Critical pin — lowercase here, opposite of buyerKycContactLine.
        assertEquals("no contact", userRowContactLine(null, null))
        // Cross-check the case difference is intentional:
        assertEquals("No contact", buyerKycContactLine(null, null))
    }

    // ---- roleChipLabel -----------------------------------------------

    @Test fun `snake_case role gets underscores replaced with spaces`() {
        assertEquals("hospital admin", roleChipLabel("hospital_admin"))
        assertEquals("hospital finance", roleChipLabel("hospital_finance"))
    }

    @Test fun `single-word role passes through`() {
        assertEquals("engineer", roleChipLabel("engineer"))
        assertEquals("founder", roleChipLabel("founder"))
    }

    @Test fun `null role surfaces as lowercase unknown`() {
        // Pin lowercase — the chip's whole typography is lowercase;
        // a Title-case "Unknown" would clash visually.
        assertEquals("unknown", roleChipLabel(null))
    }

    @Test fun `multi-underscore role replaces all underscores`() {
        assertEquals("super hospital admin", roleChipLabel("super_hospital_admin"))
    }

    // ---- userRowIntegrityPillText ------------------------------------

    @Test fun `integrity pill text prefixes the warning sign and suffixes integrity`() {
        assertEquals("⚠ 3 integrity", userRowIntegrityPillText(3))
    }

    @Test fun `integrity unit stays singular regardless of count (no plural)`() {
        // Pin — never "integrities". The label reads "N integrity
        // [failures]" with the noun elided.
        assertEquals("⚠ 1 integrity", userRowIntegrityPillText(1))
        assertEquals("⚠ 5 integrity", userRowIntegrityPillText(5))
        assertEquals("⚠ 42 integrity", userRowIntegrityPillText(42))
    }

    @Test fun `warning glyph is U+26A0`() {
        val text = userRowIntegrityPillText(1)
        assertTrue(text.startsWith("⚠"))
        // Codepoint: U+26A0
        assertEquals(0x26A0, text[0].code)
    }
}
