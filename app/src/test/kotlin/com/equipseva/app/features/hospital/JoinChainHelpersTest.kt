package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1444 join-a-chain invite-token gate. */
class JoinChainHelpersTest {

    @Test fun `token gate needs a non-trivial trimmed length`() {
        // Server tokens are two hyphen-stripped UUIDs (~64 hex chars).
        assertEquals(true, isValidInviteToken("a".repeat(64)))
        assertEquals(true, isValidInviteToken("  ${"b".repeat(16)}  "))
        assertEquals(false, isValidInviteToken("short"))
        assertEquals(false, isValidInviteToken("   "))
        assertEquals(false, isValidInviteToken(""))
    }
}
