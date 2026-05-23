package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the KYC input sanitizers for Aadhaar + PAN. Both gates are
 * critical defense against unicode-digit smuggling: Char.isDigit()
 * and Char.isLetterOrDigit() are Unicode-aware (accept Devanagari
 * "१२३" / "५" and Arabic-Indic "٥"), which pass the take(N) cap on
 * the client but fail server-side validation as a silent "invalid
 * Aadhaar / PAN".
 *
 * The sanitizers force ASCII-only:
 *   * Aadhaar: 12 digits 0-9
 *   * PAN: 10 chars, uppercase A-Z + 0-9
 */
class SanitizeAadhaarAndPanTest {

    // ---- Aadhaar ----

    @Test fun `aadhaar passes clean 12-digit input through unchanged`() {
        assertEquals("234123412346", sanitizeAadhaarInput("234123412346"))
    }

    @Test fun `aadhaar truncates input over 12 digits`() {
        assertEquals("234123412346", sanitizeAadhaarInput("23412341234699"))
    }

    @Test fun `aadhaar strips spaces and dashes from user-typed input`() {
        // "2341 2341 2346" / "2341-2341-2346" are common copy-paste shapes.
        assertEquals("234123412346", sanitizeAadhaarInput("2341 2341 2346"))
        assertEquals("234123412346", sanitizeAadhaarInput("2341-2341-2346"))
    }

    @Test fun `aadhaar rejects Devanagari numerals`() {
        // "१२३४" passes Char.isDigit() but the Verhoeff checksum
        // assumes ASCII digit codepoints — strip non-ASCII to fall
        // back to a "too short" gate downstream rather than silent
        // server-side validation failure.
        assertEquals("", sanitizeAadhaarInput("१२३४५६७८९०१२"))
    }

    @Test fun `aadhaar mixed input keeps only ASCII digits`() {
        assertEquals("12345", sanitizeAadhaarInput("1२2345abc"))
    }

    @Test fun `aadhaar blank input yields empty`() {
        assertEquals("", sanitizeAadhaarInput(""))
        assertEquals("", sanitizeAadhaarInput("   "))
    }

    // ---- PAN ----

    @Test fun `pan passes clean 10-char input through unchanged`() {
        assertEquals("ABCDE1234F", sanitizePanInput("ABCDE1234F"))
    }

    @Test fun `pan uppercases lowercase input`() {
        // Users frequently paste a PAN that was typed in lower case;
        // the server's CHECK enforces uppercase, so the client
        // normalises before submission.
        assertEquals("ABCDE1234F", sanitizePanInput("abcde1234f"))
    }

    @Test fun `pan caps at 10 chars`() {
        assertEquals("ABCDE1234F", sanitizePanInput("ABCDE1234FGGGG"))
    }

    @Test fun `pan strips spaces from user input`() {
        assertEquals("ABCDE1234F", sanitizePanInput("ABCDE 1234 F"))
    }

    @Test fun `pan rejects non-ASCII (Unicode digits and letters)`() {
        // Devanagari "५" passes isLetterOrDigit() but the server's
        // regex matches ASCII only. Strip the Devanagari chars; the
        // ASCII A-Z + 0-9 survivors stitch together and the result
        // is too short (5 letter prefix + F = 6 chars) to pass the
        // length gate. Pin so the strip semantics stay strict.
        assertEquals("ABCDEF", sanitizePanInput("ABCDE५५५५F"))
    }

    @Test fun `pan strips punctuation`() {
        // "ABCDE-1234-F" round-trips through paste; pin so it
        // normalises to the 10-char wire form.
        assertEquals("ABCDE1234F", sanitizePanInput("ABCDE-1234-F"))
    }

    @Test fun `pan empty input yields empty`() {
        assertEquals("", sanitizePanInput(""))
        assertEquals("", sanitizePanInput("   "))
    }

    @Test fun `pan keeps the wire ordering (no sort or reshuffle)`() {
        // Defensive — pin so a future refactor doesn't accidentally
        // reorder via toCharArray().sortedBy or similar.
        assertEquals("F1234EDCBA", sanitizePanInput("f1234edcba"))
    }
}
