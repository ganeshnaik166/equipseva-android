package com.equipseva.app.features.profile

import com.equipseva.app.core.util.initialsOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ProfileHeroInitialsTest {

    @Test fun `two-word name returns first letter of each, uppercased`() {
        assertEquals("AR", profileHeroInitials("Asha Rao"))
    }

    @Test fun `one-word name returns first letter`() {
        assertEquals("Z", profileHeroInitials("Zara"))
    }

    @Test fun `more than two words takes only first two via split limit`() {
        // split(' ', limit=2) gives ["John", "Doe Smith"] — first()
        // of each token is 'J' and 'D'.
        assertEquals("JD", profileHeroInitials("John Doe Smith"))
    }

    @Test fun `empty name falls back to U not question mark`() {
        // Critical pin — "U" (for "User"), distinct from initialsOf's
        // "?" fallback. Profile hero is user's own screen; "U" is
        // sensible default for an unnamed self-record.
        assertEquals("U", profileHeroInitials(""))
    }

    @Test fun `whitespace-only name falls back to U via ifBlank`() {
        assertEquals("U", profileHeroInitials("   "))
    }

    @Test fun `cross-helper distinction — Profile uses U, initialsOf uses ?`() {
        // Pin the asymmetric fallbacks so a unifying refactor doesn't
        // change Profile's "U" to "?".
        assertNotEquals(
            profileHeroInitials(""),
            initialsOf(""),
        )
        assertEquals("U", profileHeroInitials(""))
        assertEquals("?", initialsOf(""))
    }

    @Test fun `case is uppercased even if input is lowercase`() {
        assertEquals("AR", profileHeroInitials("asha rao"))
    }
}
