package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class StringsTest {

    // Round 396 — prettyKey is the display formatter for enum storage
    // keys (equipment_category, repair_priority, etc.). Surfaces across
    // founder Categories, request-service wizard, AMC wizard chip rows.

    @Test fun `snake_case is title-cased word by word`() {
        assertEquals("Image Processor", prettyKey("image_processor"))
    }

    @Test fun `kebab-case is title-cased word by word`() {
        assertEquals("Ct Scanner", prettyKey("ct-scanner"))
    }

    @Test fun `mixed snake and kebab handled`() {
        assertEquals("Auto Renew Window", prettyKey("auto_renew-window"))
    }

    @Test fun `single token capitalized`() {
        assertEquals("Imaging", prettyKey("imaging"))
    }

    @Test fun `empty string returns empty`() {
        assertEquals("", prettyKey(""))
    }

    @Test fun `already title-cased input remains stable`() {
        // First-char-of-each-token is uppercased, but rest of token is
        // not touched. So "Ct Scanner" stays "Ct Scanner" if dashed.
        assertEquals("Ct Scanner", prettyKey("Ct-Scanner"))
    }

    @Test fun `trailing delimiter yields trailing empty token`() {
        // Implementation joins all tokens (including empty) with " ",
        // so "imaging_" → "Imaging " (trailing space). Lock behavior so
        // future refactor doesn't silently change it.
        assertEquals("Imaging ", prettyKey("imaging_"))
    }

    @Test fun `consecutive delimiters yield empty middle token`() {
        // "x__y" splits as ["x", "", "y"] → "X  Y" (double space).
        assertEquals("X  Y", prettyKey("x__y"))
    }
}
