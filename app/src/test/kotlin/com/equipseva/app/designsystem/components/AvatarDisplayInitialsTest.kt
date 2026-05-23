package com.equipseva.app.designsystem.components

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * Pins avatarDisplayInitials Turkish-locale regression target.
 *
 * Default-locale uppercase() on a Turkish device maps 'i' → 'İ'
 * (dotted capital) and 'I' → 'ı' (dotless lowercase). This is the
 * correct Turkish casing rule but corrupts English-name initials.
 * Pin Locale.ENGLISH on the uppercase() call.
 */
class AvatarDisplayInitialsTest {

    @Test fun `two-char input passes through uppercased`() {
        assertEquals("AB", avatarDisplayInitials("ab"))
    }

    @Test fun `single-char input passes through uppercased`() {
        assertEquals("A", avatarDisplayInitials("a"))
    }

    @Test fun `empty input returns empty`() {
        assertEquals("", avatarDisplayInitials(""))
    }

    @Test fun `three-or-more-char input is truncated to first two`() {
        // The helper does a raw take(2) on whatever the caller passes
        // (callers compose initials separately via initialsOf). Pin
        // so a refactor that "improved" the helper by adding word-
        // splitting doesn't slip in.
        assertEquals("AS", avatarDisplayInitials("Asha"))
        assertEquals("JO", avatarDisplayInitials("john doe smith"))
    }

    @Test fun `i char uppercases to I not Turkish dotted-capital even on tr-TR`() {
        // Critical regression target.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"))
            assertEquals("IG", avatarDisplayInitials("ig"))
            assertEquals("LI", avatarDisplayInitials("li"))
            // Specifically check codepoint — dotted capital I is U+0130.
            val out = avatarDisplayInitials("ii")
            assertEquals(0x49, out[0].code) // ASCII capital I = 0x49
            assertEquals(0x49, out[1].code)
            assertEquals(false, out.contains(0x130.toChar())) // not İ
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `already-uppercase input stays uppercase`() {
        assertEquals("AB", avatarDisplayInitials("AB"))
    }

    @Test fun `digit input passes through (uppercase is no-op on digits)`() {
        assertEquals("9I", avatarDisplayInitials("9i"))
    }
}
