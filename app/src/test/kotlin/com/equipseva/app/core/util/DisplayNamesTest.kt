package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [sanitizeServerName] — the guard against server RPCs that
 * coalesce a null profiles.full_name to a literal like "(unnamed)".
 */
class DisplayNamesTest {

    @Test fun `real names pass through (trimmed)`() {
        assertEquals("Dr. Meera Nair", sanitizeServerName("Dr. Meera Nair"))
        assertEquals("Acme Hospital", sanitizeServerName("  Acme Hospital  "))
    }

    @Test fun `null and blank are absent`() {
        assertNull(sanitizeServerName(null))
        assertNull(sanitizeServerName(""))
        assertNull(sanitizeServerName("   "))
    }

    @Test fun `server placeholder sentinels are treated as absent`() {
        assertNull(sanitizeServerName("(unnamed)"))
        assertNull(sanitizeServerName("(unknown)"))
        assertNull(sanitizeServerName("(no name)"))
        assertNull(sanitizeServerName("(UNNAMED)"))
        assertNull(sanitizeServerName("  (unnamed)  "))
    }

    @Test fun `parens elsewhere in a real name are preserved`() {
        assertEquals("Dr. (Meera) Nair", sanitizeServerName("Dr. (Meera) Nair"))
    }
}
