package com.equipseva.app.core.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The signature check accepts a comma-separated `EXPECTED_CERT_SHA256`
 * because we need to ship BOTH the upload-key fingerprint AND the Play
 * App Signing key fingerprint in a single CI secret (Play Console re-signs
 * after upload). The parser is tiny but easy to break with a typo (e.g.
 * dropping `.filter { it.isNotEmpty() }` would turn `"abc,"` into a list
 * that includes "" and the check then matches every cert).
 */
class SignatureVerifierFingerprintTest {

    @Test fun `single fingerprint with no comma is returned as-is`() {
        val out = SignatureVerifier.parseExpectedFingerprints("abc123==")
        assertEquals(listOf("abc123=="), out)
    }

    @Test fun `multiple fingerprints split on comma`() {
        val out = SignatureVerifier.parseExpectedFingerprints("abc123==,def456==")
        assertEquals(listOf("abc123==", "def456=="), out)
    }

    @Test fun `whitespace around entries is trimmed`() {
        val out = SignatureVerifier.parseExpectedFingerprints("  abc123==  ,\tdef456==\n")
        assertEquals(listOf("abc123==", "def456=="), out)
    }

    @Test fun `empty entries from trailing or duplicate commas are dropped`() {
        // Without the .filter step, the Verdict.Ok arm of the verify check
        // would `expected.any { it.equals(actual, ignoreCase = true) }` —
        // and would *match an empty string against an empty actual* if
        // currentCertSha256 ever returned an unexpected blank. Pin the
        // safety net.
        val out = SignatureVerifier.parseExpectedFingerprints("abc,,def,")
        assertEquals(listOf("abc", "def"), out)
    }

    @Test fun `blank-only string yields an empty list which signals "skip the check"`() {
        // The verify() caller uses isEmpty() to mean "no expected
        // fingerprints configured, fall through to Verdict.Unknown".
        assertTrue(SignatureVerifier.parseExpectedFingerprints("").isEmpty())
        assertTrue(SignatureVerifier.parseExpectedFingerprints("   ").isEmpty())
        assertTrue(SignatureVerifier.parseExpectedFingerprints(",, ,").isEmpty())
    }
}
