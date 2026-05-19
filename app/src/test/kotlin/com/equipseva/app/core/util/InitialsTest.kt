package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class InitialsTest {

    // Round 395 — initialsOf is used by every avatar fallback (HomeHub
    // carousel, engineer public profile, repeat-booking nudge, chat,
    // conversations, repair job detail). Centralising broke previous
    // ad-hoc `name.take(2)` callsites that produced wrong initials
    // like "RA" instead of "RK" for "Ramesh Kumar".

    @Test fun `two-token name returns two initials`() {
        assertEquals("RK", initialsOf("Ramesh Kumar"))
    }

    @Test fun `single token name returns one initial`() {
        assertEquals("P", initialsOf("Priyanka"))
    }

    @Test fun `three or more tokens still returns first two`() {
        // limit=2 in the implementation caps to first two tokens.
        assertEquals("RK", initialsOf("Ramesh Kumar Verma"))
    }

    @Test fun `empty input returns question mark`() {
        assertEquals("?", initialsOf(""))
    }

    @Test fun `whitespace-only input returns question mark`() {
        assertEquals("?", initialsOf("   "))
    }

    @Test fun `lowercase input is uppercased`() {
        assertEquals("AB", initialsOf("anita bose"))
    }

    @Test fun `mixed case preserved as uppercase`() {
        assertEquals("MC", initialsOf("McGuire Connor"))
    }

    @Test fun `leading whitespace tolerated`() {
        // First split-token is empty string when name starts with space;
        // it yields no initial, second token contributes "P".
        assertEquals("P", initialsOf(" Priyanka"))
    }

    @Test fun `unicode names handled`() {
        // Devanagari first code point of each token. Note Kotlin
        // uppercaseChar() returns the same code point for Devanagari
        // letters (no case in the script).
        assertEquals("रम", initialsOf("राकेश मोहन"))
    }

    @Test fun `single character token works`() {
        assertEquals("AB", initialsOf("A B"))
    }
}
