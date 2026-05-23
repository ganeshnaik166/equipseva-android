package com.equipseva.app.designsystem.components

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanConfirmDeleteAccountTest {

    @Test fun `non-blank password and not deleting enables`() {
        assertTrue(canConfirmDeleteAccount("Secret123", deleting = false))
    }

    @Test fun `blank password blocks (re-auth gate)`() {
        assertFalse(canConfirmDeleteAccount("", false))
        assertFalse(canConfirmDeleteAccount("   ", false))
    }

    @Test fun `deleting blocks regardless of password (prevents double-tap)`() {
        assertFalse(canConfirmDeleteAccount("Secret123", deleting = true))
    }
}
