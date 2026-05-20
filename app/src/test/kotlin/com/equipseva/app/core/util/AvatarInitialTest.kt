package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pure single-letter avatar-initial builder used by the founder KYC
 * queue + users list (and any other surface that needs a fallback
 * chain). Two-letter chat-style initials live separately because the
 * policy is different (split on whitespace, take two).
 */
class AvatarInitialTest {

    @Test fun `uses first letter of primary uppercased`() {
        assertEquals("R", avatarInitial("Ravi"))
        assertEquals("R", avatarInitial("ravi"))
        assertEquals("Ä", avatarInitial("änna"))
    }

    @Test fun `falls back to secondary when primary is null`() {
        assertEquals("X", avatarInitial(null, secondary = "xena@example.com"))
    }

    @Test fun `falls back to secondary when primary is blank`() {
        // firstOrNull returns null on an empty string. Pin the behaviour
        // so a refactor that swaps to `.first()` (which throws) gets
        // caught here.
        assertEquals("X", avatarInitial("", secondary = "xena@example.com"))
    }

    @Test fun `falls back to blankFallback when both are missing`() {
        assertEquals("?", avatarInitial(null, secondary = null))
        assertEquals("?", avatarInitial("", secondary = ""))
    }

    @Test fun `respects a custom blankFallback`() {
        // Engineer KYC queue rows fall back to "E" instead of "?".
        assertEquals("E", avatarInitial(null, blankFallback = "E"))
        assertEquals("E", avatarInitial("", null, blankFallback = "E"))
    }

    @Test fun `primary wins over secondary when both present`() {
        assertEquals("R", avatarInitial("Ravi", secondary = "xena@example.com"))
    }

    @Test fun `non-letter first char still returns that char uppercased`() {
        // Digits / symbols are upper-cased to themselves; the renderer
        // will display whatever lands in the chip. Pin so a refactor
        // that adds a "letter-only" filter doesn't silently introduce
        // a regression.
        assertEquals("1", avatarInitial("1234"))
        assertEquals("@", avatarInitial("@handle"))
    }
}
