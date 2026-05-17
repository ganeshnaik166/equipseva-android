package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class PhoneNormalizationTest {

    @Test fun `empty input passes through`() {
        assertEquals("", normalizeIndiaMobileInput(""))
    }

    @Test fun `bare prefix stays`() {
        assertEquals("+91", normalizeIndiaMobileInput("+91"))
    }

    @Test fun `valid full E164 stays`() {
        assertEquals("+919876543210", normalizeIndiaMobileInput("+919876543210"))
    }

    @Test fun `paste full number on top of autoprefix dedups to 13 chars`() {
        // User typed/pasted "+919876543210" but field already had "+91" →
        // raw concat is "+91+919876543210" → after filter "+91919876543210" (15 chars).
        // Length>13 + +9191 prefix + dedup-candidate exactly 13 chars → strip.
        assertEquals("+919876543210", normalizeIndiaMobileInput("+91919876543210"))
    }

    @Test fun `11 digit typo past prefix does NOT lose a digit`() {
        // Round 287 regression case: cleaned = "+9191234567890" (14 chars).
        // Old code would strip 5 chars → "+91234567890" (12 chars, drops one mobile digit).
        // New behavior: leave the malformed input visible so user corrects it.
        assertEquals("+9191234567890", normalizeIndiaMobileInput("+9191234567890"))
    }

    @Test fun `unicode devanagari digits are dropped`() {
        // Devanagari 9876543210 in Hindi numerals — Char.isDigit() would
        // accept these but Supabase E.164 parser rejects. Our filter keeps
        // only ASCII '0'..'9'.
        assertEquals("+91", normalizeIndiaMobileInput("+91९८७६५४३२१०"))
    }

    @Test fun `letters are dropped`() {
        assertEquals("+919876543210", normalizeIndiaMobileInput("+91-9876-543-210"))
    }

    @Test fun `over 16 chars is capped`() {
        assertEquals(16, normalizeIndiaMobileInput("+91987654321098765").length)
    }

    @Test fun `bare + alone is preserved`() {
        assertEquals("+", normalizeIndiaMobileInput("+"))
    }

    @Test fun `+ only after first position is dropped`() {
        // "+91+91..." — the second + is at position 3, filter drops it,
        // leaving "+91919876543210" → dedup → "+919876543210".
        assertEquals("+919876543210", normalizeIndiaMobileInput("+91+919876543210"))
    }
}
