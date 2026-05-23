package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Test

class UnreadBadgeLabelTest {

    @Test fun `1 reads 1`() {
        assertEquals("1", unreadBadgeLabel(1))
    }

    @Test fun `99 reads 99 not 99+`() {
        // Critical pin — 99 is the LAST exact-count tier.
        assertEquals("99", unreadBadgeLabel(99))
    }

    @Test fun `100 reads 99+`() {
        // Critical pin — 100 is the first capped tier.
        assertEquals("99+", unreadBadgeLabel(100))
    }

    @Test fun `large count reads 99+`() {
        assertEquals("99+", unreadBadgeLabel(247))
        assertEquals("99+", unreadBadgeLabel(9999))
    }

    @Test fun `0 reads 0`() {
        // Caller gates on > 0 to render the badge, but pin total
        // shape.
        assertEquals("0", unreadBadgeLabel(0))
    }

    @Test fun `99-plus literal is preserved verbatim`() {
        // Pin "99+" with ASCII '+' — a refactor to "99⁺" (superscript)
        // would diverge from convention.
        val out = unreadBadgeLabel(500)
        assertEquals("99+", out)
    }
}
