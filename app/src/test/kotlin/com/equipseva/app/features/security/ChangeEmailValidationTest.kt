package com.equipseva.app.features.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Inline validation for the Change-email screen on Profile. Direct
 * profile.email write (no auth-email rotation) — the screen still
 * validates shape so a typo doesn't land on the engineer's public
 * profile and break hospital outreach.
 */
class ChangeEmailValidationTest {

    @Test fun `valid email passes`() {
        assertNull(validateChangeEmail("user@example.com"))
        assertNull(validateChangeEmail("first.last+tag@sub.example.co"))
    }

    @Test fun `blank input gets the empty-field copy`() {
        // Note: the VM trims before calling — pin the trimmed contract
        // since whitespace-only is what the VM would forward.
        assertEquals("Enter your new email", validateChangeEmail(""))
    }

    @Test fun `bad shape gets the validity copy`() {
        assertEquals("Enter a valid email address", validateChangeEmail("no-at-sign"))
        assertEquals("Enter a valid email address", validateChangeEmail("user@nodot"))
        assertEquals("Enter a valid email address", validateChangeEmail("user@x.c"))
    }
}
