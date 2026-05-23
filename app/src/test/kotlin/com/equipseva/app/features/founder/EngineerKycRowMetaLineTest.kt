package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineerKycRowMetaLineTest {

    @Test fun `all three parts present`() {
        assertEquals(
            "5 yrs exp · 25km radius · Hyderabad, Telangana",
            engineerKycRowMetaLine(5, 25, "Hyderabad", "Telangana"),
        )
    }

    @Test fun `experience years uses yrs exp short form`() {
        // Pin "yrs exp" (NOT "years experience" or "yoe" or "yrs").
        val out = engineerKycRowMetaLine(5, null, null, null)
        assertEquals("5 yrs exp", out)
    }

    @Test fun `service radius uses km radius with no leading space`() {
        // Pin "25km radius" — compact form, no space between km and
        // the digit. Refactor to "25 km radius" would widen the row.
        val out = engineerKycRowMetaLine(null, 25, null, null)
        assertEquals("25km radius", out)
    }

    @Test fun `city alone gives city only (no comma)`() {
        assertEquals(
            "Hyderabad",
            engineerKycRowMetaLine(null, null, "Hyderabad", null),
        )
    }

    @Test fun `state alone gives state only`() {
        assertEquals(
            "Telangana",
            engineerKycRowMetaLine(null, null, null, "Telangana"),
        )
    }

    @Test fun `city + state joined with comma-space`() {
        assertEquals(
            "Hyderabad, Telangana",
            engineerKycRowMetaLine(null, null, "Hyderabad", "Telangana"),
        )
    }

    @Test fun `all null returns blank string (caller hides Text)`() {
        assertEquals(
            "",
            engineerKycRowMetaLine(null, null, null, null),
        )
    }

    @Test fun `part order — experience first then radius then location`() {
        // Pin the founder-triage priority order.
        val out = engineerKycRowMetaLine(5, 25, "Hyderabad", null)
        val parts = out.split(" · ")
        assertEquals("5 yrs exp", parts[0])
        assertEquals("25km radius", parts[1])
        assertEquals("Hyderabad", parts[2])
    }

    @Test fun `middle dot separators are U+00B7 not bullet`() {
        val out = engineerKycRowMetaLine(1, 1, "X", "Y")
        assertTrue(out.contains(" · "))
    }

    @Test fun `partial - experience + radius without location`() {
        assertEquals(
            "5 yrs exp · 25km radius",
            engineerKycRowMetaLine(5, 25, null, null),
        )
    }

    @Test fun `partial - radius + location without experience`() {
        assertEquals(
            "25km radius · Hyderabad",
            engineerKycRowMetaLine(null, 25, "Hyderabad", null),
        )
    }

    @Test fun `partial - experience + location without radius`() {
        assertEquals(
            "5 yrs exp · Hyderabad",
            engineerKycRowMetaLine(5, null, "Hyderabad", null),
        )
    }
}
