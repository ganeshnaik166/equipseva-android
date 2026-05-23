package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EngineerAmcVisitsSubtitleTest {

    @Test fun `1 row reads singular visit`() {
        // Critical pin — never "1 visits".
        assertEquals("1 visit", engineerAmcVisitsSubtitle(1))
    }

    @Test fun `2 rows reads plural visits`() {
        assertEquals("2 visits", engineerAmcVisitsSubtitle(2))
    }

    @Test fun `0 rows returns null`() {
        assertNull(engineerAmcVisitsSubtitle(0))
    }

    @Test fun `negative defensive returns null`() {
        assertNull(engineerAmcVisitsSubtitle(-1))
    }

    @Test fun `large count interpolates verbatim with plural`() {
        assertEquals("42 visits", engineerAmcVisitsSubtitle(42))
    }
}
