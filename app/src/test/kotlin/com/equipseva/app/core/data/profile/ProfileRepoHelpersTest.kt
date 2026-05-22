package com.equipseva.app.core.data.profile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two pure helpers behind SupabaseProfileRepository's
 * fetchDisplayNames. Both run on every chat counterpart / job
 * participant / search-result resolve path, so a regression in
 * either silently misrenders the user-name strip across surfaces.
 */
class ProfileRepoHelpersTest {

    // ---- sanitiseUserIdList ----

    @Test fun `removes blank ids and dedupes`() {
        assertEquals(
            listOf("u1", "u2"),
            sanitiseUserIdList(listOf("u1", "", "  ", "u2", "u1")),
        )
    }

    @Test fun `preserves first-occurrence order on dedupe`() {
        // Stable order matters because the chat-row map fall-through
        // is the first non-blank id in the participants list. Pin
        // distinct() to keep first-seen.
        assertEquals(
            listOf("u-third", "u-first", "u-second"),
            sanitiseUserIdList(listOf("u-third", "u-first", "u-third", "u-second", "u-first")),
        )
    }

    @Test fun `empty input yields empty`() {
        assertTrue(sanitiseUserIdList(emptyList()).isEmpty())
    }

    @Test fun `all-blank input yields empty`() {
        assertTrue(sanitiseUserIdList(listOf("", " ", "\t", "\n")).isEmpty())
    }

    // ---- profileDisplayNameFallback ----

    @Test fun `non-blank fullName passes through`() {
        assertEquals("Ravi Kumar", profileDisplayNameFallback("Ravi Kumar"))
    }

    @Test fun `null fullName folds to literal User`() {
        // Critical: the literal "User" is the safest non-PII
        // placeholder — never expose email/phone here.
        assertEquals("User", profileDisplayNameFallback(null))
    }

    @Test fun `blank fullName folds to User`() {
        assertEquals("User", profileDisplayNameFallback(""))
        assertEquals("User", profileDisplayNameFallback("   "))
        assertEquals("User", profileDisplayNameFallback("\n\t"))
    }

    @Test fun `fullName with leading-trailing whitespace passes through unchanged`() {
        // The repo doesn't trim — display layer can decide. Pin so a
        // future trim() refactor surfaces (might be desired but
        // should be reviewed).
        assertEquals("  Ravi Kumar  ", profileDisplayNameFallback("  Ravi Kumar  "))
    }
}
