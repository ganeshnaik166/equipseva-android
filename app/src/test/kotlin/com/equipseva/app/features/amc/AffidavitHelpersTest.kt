package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1446 AMC affidavit aadhaar-last-4 gate. */
class AffidavitHelpersTest {

    @Test fun `aadhaar last4 is optional but 4 digits when present`() {
        assertEquals(true, isValidAadhaarLast4(""))
        assertEquals(true, isValidAadhaarLast4("   "))
        assertEquals(true, isValidAadhaarLast4("1234"))
        assertEquals(true, isValidAadhaarLast4("  5678  "))
        assertEquals(false, isValidAadhaarLast4("123"))
        assertEquals(false, isValidAadhaarLast4("12345"))
        assertEquals(false, isValidAadhaarLast4("12a4"))
    }
}
