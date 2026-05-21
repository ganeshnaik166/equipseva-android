package com.equipseva.app.core.security

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the three-state [SignatureVerifier.Verdict] enum. The verdict
 * shape is part of the contract the launcher reads on every
 * cold-start; an addition or rename here without coordinating with
 * the TamperPolicy reader would silently leak unmatched-cert installs.
 *
 * Order matters: Unknown sits between Ok and Tampered so a future
 * three-way branch (`when (verdict) { Ok -> .., Unknown -> .., Tampered -> .. }`)
 * stays exhaustive.
 */
class SignatureVerifierVerdictTest {

    @Test fun `three verdicts total`() {
        assertEquals(3, SignatureVerifier.Verdict.entries.size)
    }

    @Test fun `verdict names are the pinned tokens`() {
        // Pin the names so a refactor to e.g. "Pass / Skip / Fail"
        // surfaces in review (would force every TamperPolicy reader
        // to update its when() branches).
        assertEquals("Ok", SignatureVerifier.Verdict.Ok.name)
        assertEquals("Unknown", SignatureVerifier.Verdict.Unknown.name)
        assertEquals("Tampered", SignatureVerifier.Verdict.Tampered.name)
    }

    @Test fun `verdict order is Ok then Unknown then Tampered`() {
        // ordinal matters for exhaustive when() across the TamperPolicy
        // reader — keep the existing ordering.
        assertEquals(0, SignatureVerifier.Verdict.Ok.ordinal)
        assertEquals(1, SignatureVerifier.Verdict.Unknown.ordinal)
        assertEquals(2, SignatureVerifier.Verdict.Tampered.ordinal)
    }
}
