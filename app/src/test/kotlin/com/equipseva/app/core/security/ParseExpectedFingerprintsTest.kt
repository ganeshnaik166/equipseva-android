package com.equipseva.app.core.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the comma-separated fingerprint parser used by
 * [SignatureVerifier]. The build-config carries BOTH the upload-key
 * fingerprint (for locally-built AABs / sideloaded test APKs) and
 * the Play App Signing key fingerprint (for Play-distributed
 * installs). They're packed into a single comma-separated string
 * because BuildConfig fields are scalar; the parser handles
 * whitespace tolerance + skips empty entries.
 *
 * A regression that dropped trim/empty filtering would either fail
 * the cert match on a config with trailing whitespace (every Play
 * install lands as Tampered) or pass a blank "" through as a valid
 * fingerprint (defeats the gate entirely).
 */
class ParseExpectedFingerprintsTest {

    @Test fun `single fingerprint passes through verbatim`() {
        assertEquals(
            listOf("AB:CD:EF"),
            SignatureVerifier.parseExpectedFingerprints("AB:CD:EF"),
        )
    }

    @Test fun `comma-separated fingerprints split cleanly`() {
        assertEquals(
            listOf("AB:CD", "12:34", "FF:00"),
            SignatureVerifier.parseExpectedFingerprints("AB:CD,12:34,FF:00"),
        )
    }

    @Test fun `whitespace around each fingerprint is trimmed`() {
        // BuildConfig literal might land padded by gradle interpolation.
        assertEquals(
            listOf("AB:CD", "12:34"),
            SignatureVerifier.parseExpectedFingerprints("  AB:CD ,  12:34  "),
        )
    }

    @Test fun `empty entries from double-commas are dropped`() {
        // Defensive — a copy-paste error that leaves "AB:CD,,12:34"
        // should not surface an empty string as a valid fingerprint.
        assertEquals(
            listOf("AB:CD", "12:34"),
            SignatureVerifier.parseExpectedFingerprints("AB:CD,,12:34,"),
        )
    }

    @Test fun `blank input yields empty list (no phantom entries)`() {
        // Blank config means "no fingerprint set" — verify() skips
        // the check in that case rather than failing every install.
        assertTrue(SignatureVerifier.parseExpectedFingerprints("").isEmpty())
        assertTrue(SignatureVerifier.parseExpectedFingerprints("   ").isEmpty())
        assertTrue(SignatureVerifier.parseExpectedFingerprints(",,").isEmpty())
    }

    @Test fun `case is preserved (comparison happens at verify time)`() {
        // The parser doesn't lowercase — case-insensitive matching
        // is the verify()'s job. Pin so a future "tighten parser"
        // change is reviewed (would silently change the wire match).
        assertEquals(
            listOf("ab:cd"),
            SignatureVerifier.parseExpectedFingerprints("ab:cd"),
        )
        assertEquals(
            listOf("AB:CD"),
            SignatureVerifier.parseExpectedFingerprints("AB:CD"),
        )
    }
}
