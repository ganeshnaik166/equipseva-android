package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the pure derivations sitting inside KycScreen composables:
 *  - the rejected-doc label joiner used by the re-upload CTA
 *  - the Aadhaar / PAN inline hint copy
 *  - the bottom-bar stepper label
 *
 * These would otherwise need a composable-render test to verify, which
 * is expensive and brittle. Extracting them to top-level keeps the
 * branches cheap to pin.
 */
class KycScreenHelpersTest {

    /* --------- flaggedDocsLabel --------- */

    @Test fun `flaggedDocsLabel returns null on an empty list`() {
        assertNull(flaggedDocsLabel(emptyList()))
    }

    @Test fun `flaggedDocsLabel maps known keys to friendly labels`() {
        assertEquals("Aadhaar", flaggedDocsLabel(listOf("aadhaar")))
        assertEquals("selfie", flaggedDocsLabel(listOf("selfie")))
        assertEquals("certificate", flaggedDocsLabel(listOf("cert")))
    }

    @Test fun `flaggedDocsLabel joins multiple keys with comma-space`() {
        assertEquals(
            "Aadhaar, certificate",
            flaggedDocsLabel(listOf("aadhaar", "cert")),
        )
    }

    @Test fun `flaggedDocsLabel falls through unknown keys verbatim`() {
        // Forwards-compat: a server-side rejection for a new doc type
        // still renders the CTA — just with the raw key as label.
        assertEquals(
            "Aadhaar, gst_cert",
            flaggedDocsLabel(listOf("aadhaar", "gst_cert")),
        )
    }

    /* --------- aadhaarNumberHint --------- */

    @Test fun `aadhaarNumberHint empty input prompts for 12 digits`() {
        assertEquals("12 digits, no spaces", aadhaarNumberHint("", checksumOk = false))
    }

    @Test fun `aadhaarNumberHint partial input shows live progress`() {
        assertEquals("3/12 digits", aadhaarNumberHint("123", checksumOk = false))
        assertEquals("11/12 digits", aadhaarNumberHint("12345678901", checksumOk = false))
    }

    @Test fun `aadhaarNumberHint length-12 but checksum-fail flags it`() {
        assertEquals(
            "Number doesn't pass the standard Aadhaar checksum",
            aadhaarNumberHint("123456789012", checksumOk = false),
        )
    }

    @Test fun `aadhaarNumberHint valid input shows the looks-valid checkmark`() {
        assertEquals(
            "Looks valid ✓",
            aadhaarNumberHint("234123412346", checksumOk = true),
        )
    }

    /* --------- panNumberHint --------- */

    @Test fun `panNumberHint empty input shows the format example`() {
        assertEquals(
            "10 chars: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F)",
            panNumberHint("", panOk = false),
        )
    }

    @Test fun `panNumberHint partial input shows live progress`() {
        assertEquals("3/10 chars", panNumberHint("ABC", panOk = false))
        assertEquals("9/10 chars", panNumberHint("ABCDE1234", panOk = false))
    }

    @Test fun `panNumberHint length-10 but format-fail flags it`() {
        assertEquals(
            "Format must be ABCDE1234F",
            panNumberHint("AAAAA00000", panOk = false),
        )
    }

    @Test fun `panNumberHint valid input shows the looks-valid checkmark`() {
        assertEquals(
            "Looks valid ✓",
            panNumberHint("ABCDE1234F", panOk = true),
        )
    }

    /* --------- stepperNextLabel --------- */

    @Test fun `stepperNextLabel mid-flow renders Next`() {
        assertEquals("Next", stepperNextLabel(isLast = false, rejected = false))
        // Rejected status is irrelevant on non-final steps — copy must
        // not leak into Personal step.
        assertEquals("Next", stepperNextLabel(isLast = false, rejected = true))
    }

    @Test fun `stepperNextLabel last step on first submission renders Submit for review`() {
        assertEquals(
            "Submit for review",
            stepperNextLabel(isLast = true, rejected = false),
        )
    }

    @Test fun `stepperNextLabel last step after rejection renders Re-submit for review`() {
        assertEquals(
            "Re-submit for review",
            stepperNextLabel(isLast = true, rejected = true),
        )
    }
}
