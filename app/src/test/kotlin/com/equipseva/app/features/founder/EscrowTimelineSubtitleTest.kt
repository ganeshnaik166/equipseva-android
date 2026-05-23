package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EscrowTimelineSubtitleTest {

    @Test fun `1 event reads singular`() {
        assertEquals("1 event", escrowTimelineSubtitle(1))
    }

    @Test fun `2 events reads plural`() {
        assertEquals("2 events", escrowTimelineSubtitle(2))
    }

    @Test fun `0 events returns null (top bar stays clean)`() {
        assertNull(escrowTimelineSubtitle(0))
    }

    @Test fun `negative count returns null (defensive)`() {
        assertNull(escrowTimelineSubtitle(-1))
    }

    @Test fun `large count interpolates with plural`() {
        assertEquals("42 events", escrowTimelineSubtitle(42))
    }
}
