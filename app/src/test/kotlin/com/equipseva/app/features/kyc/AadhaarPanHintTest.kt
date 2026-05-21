package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the inline-hint copy under the KYC Aadhaar + PAN input
 * fields. Four states each:
 *   empty            → instructional prompt
 *   short            → progress counter (N/total)
 *   complete but bad → specific format / checksum error
 *   complete and ok  → "Looks valid ✓"
 *
 * The progress counter is the easy regression: a refactor that
 * shipped just "Looks valid ✓" or just an error on partial input
 * would lose the progress feedback that helps users see how close
 * they are to completion.
 */
class AadhaarPanHintTest {

    // ---- Aadhaar ----

    @Test fun `empty Aadhaar shows the 12-digit prompt`() {
        assertEquals("12 digits, no spaces", aadhaarNumberHint("", checksumOk = false))
    }

    @Test fun `short Aadhaar shows the progress counter`() {
        assertEquals("4/12 digits", aadhaarNumberHint("1234", checksumOk = false))
        assertEquals("11/12 digits", aadhaarNumberHint("12345678901", checksumOk = false))
    }

    @Test fun `full but bad-checksum Aadhaar shows the checksum error`() {
        // Length is 12 so the short-counter branch doesn't match;
        // checksumOk is false so the error wins.
        assertEquals(
            "Number doesn't pass the standard Aadhaar checksum",
            aadhaarNumberHint("123456789012", checksumOk = false),
        )
    }

    @Test fun `valid Aadhaar shows the looks-valid checkmark`() {
        assertEquals(
            "Looks valid ✓",
            aadhaarNumberHint("234123412346", checksumOk = true),
        )
    }

    @Test fun `Aadhaar above 12 chars treated as full + checksum-dependent`() {
        // Defensive — the input sanitizer caps at 12, but if a
        // longer string somehow leaked through, the hint should
        // still surface a meaningful state rather than crash.
        // length >= 12 falls through to the checksum branches.
        assertEquals(
            "Number doesn't pass the standard Aadhaar checksum",
            aadhaarNumberHint("1234567890123", checksumOk = false),
        )
    }

    // ---- PAN ----

    @Test fun `empty PAN shows the 10-char format prompt with example`() {
        assertEquals(
            "10 chars: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F)",
            panNumberHint("", panOk = false),
        )
    }

    @Test fun `short PAN shows progress counter`() {
        assertEquals("3/10 chars", panNumberHint("ABC", panOk = false))
        assertEquals("9/10 chars", panNumberHint("ABCDE1234", panOk = false))
    }

    @Test fun `full but bad-format PAN shows the format error`() {
        // 10 chars but pattern doesn't match — e.g. all digits.
        assertEquals(
            "Format must be ABCDE1234F",
            panNumberHint("1234567890", panOk = false),
        )
    }

    @Test fun `valid PAN shows the looks-valid checkmark`() {
        assertEquals(
            "Looks valid ✓",
            panNumberHint("ABCDE1234F", panOk = true),
        )
    }

    @Test fun `both helpers share the "Looks valid" checkmark string`() {
        // Same visual language across both fields — pin so a copy
        // tweak doesn't drift the two apart.
        assertEquals(
            aadhaarNumberHint("234123412346", true),
            panNumberHint("ABCDE1234F", true),
        )
    }
}
