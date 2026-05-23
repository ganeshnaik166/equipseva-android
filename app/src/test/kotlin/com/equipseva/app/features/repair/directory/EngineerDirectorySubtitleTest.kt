package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineerDirectorySubtitleTest {

    @Test fun `All Telangana sentinel reads across Telangana`() {
        // Critical pin — "across" not "near" when no district picked.
        assertEquals(
            "10 verified · across Telangana",
            engineerDirectorySubtitle(10, "All Telangana"),
        )
    }

    @Test fun `specific district reads near district`() {
        assertEquals(
            "5 verified · near Hyderabad",
            engineerDirectorySubtitle(5, "Hyderabad"),
        )
    }

    @Test fun `All Telangana exact sentinel match required`() {
        // Pin — case-sensitive exact match. A refactor to
        // "all telangana" (lowercase) would surface the "near"
        // branch incorrectly.
        val out = engineerDirectorySubtitle(5, "all telangana")
        assertTrue(out.contains("near all telangana"))
    }

    @Test fun `near branch frames distance not scope`() {
        // Pin "near" semantics — proximity to the picked district.
        val out = engineerDirectorySubtitle(1, "Warangal")
        assertTrue(out.contains(" · near Warangal"))
    }

    @Test fun `across branch frames scope not distance`() {
        // Pin "across" semantics — covers a whole region.
        val out = engineerDirectorySubtitle(1, "All Telangana")
        assertTrue(out.contains(" · across Telangana"))
    }

    @Test fun `0 count interpolates verbatim (defensive)`() {
        assertEquals(
            "0 verified · across Telangana",
            engineerDirectorySubtitle(0, "All Telangana"),
        )
    }

    @Test fun `middle dot is U+00B7`() {
        val out = engineerDirectorySubtitle(1, "Hyderabad")
        assertTrue(out.contains(" · "))
    }
}
