package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FounderDashboardSubtitleTest {

    @Test fun `non-null email reads Founder middle-dot email`() {
        assertEquals(
            "Founder · ganesh@example.com",
            founderDashboardSubtitle("ganesh@example.com"),
        )
    }

    @Test fun `null email reads bare Founder`() {
        // Cold-load before session resolves — no email yet but the
        // role label still surfaces.
        assertEquals("Founder", founderDashboardSubtitle(null))
    }

    @Test fun `Founder prefix preserved on both branches`() {
        // Critical pin — role-confirmation signal that distinguishes
        // admin dashboard from a regular profile screen.
        assertTrue(founderDashboardSubtitle("x@y.com").startsWith("Founder"))
        assertTrue(founderDashboardSubtitle(null).startsWith("Founder"))
    }

    @Test fun `middle dot is U+00B7 not bullet`() {
        val out = founderDashboardSubtitle("x@y.com")
        assertTrue(out.contains(" · "))
        assertEquals(false, out.contains(" • "))
    }

    @Test fun `empty email string passes through verbatim (not folded)`() {
        // Pin exact null gate — empty string is preserved as the
        // suffix. Wire shouldn't allow this, but pin total shape.
        assertEquals("Founder · ", founderDashboardSubtitle(""))
    }
}
