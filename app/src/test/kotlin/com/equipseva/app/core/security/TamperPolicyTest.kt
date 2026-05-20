package com.equipseva.app.core.security

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Unit coverage for the integrity-verification branch of [TamperPolicy].
 *
 * The signature-verdict branch (Tampered → TamperedSignatureException) gates
 * on `BuildConfig.EXPECTED_CERT_SHA256.isNotBlank()`. Under the local /
 * CI debug variant that BuildConfig field is empty (the upload-key fingerprint
 * is only filled in after the first Play Console upload — see PENDING.md #14),
 * so the signature branch is effectively a no-op here and cannot be exercised
 * without rebuilding with a non-blank fingerprint. We instead pin the
 * "blank cert short-circuits the signature check" invariant explicitly.
 */
class TamperPolicyTest {

    @Test fun `success when integrity verifier returns true`() = runTest {
        val verifier = RecordingIntegrityVerifier(Result.success(true))
        val policy = TamperPolicy(verifier)

        val outcome = policy.enforce("auth_change")

        assertTrue(outcome.isSuccess)
        assertEquals(listOf("auth_change"), verifier.calls)
    }

    @Test fun `IntegrityFailedException when verifier returns false`() = runTest {
        val verifier = RecordingIntegrityVerifier(Result.success(false))
        val policy = TamperPolicy(verifier)

        val outcome = policy.enforce("delete_account")

        assertTrue(outcome.isFailure)
        val ex = outcome.exceptionOrNull()
        assertNotNull(ex)
        assertTrue(ex is TamperPolicy.IntegrityFailedException)
        assertTrue(ex!!.message!!.contains("delete_account"))
    }

    @Test fun `verifier failure propagates unchanged`() = runTest {
        val cause = IOException("offline")
        val verifier = RecordingIntegrityVerifier(Result.failure(cause))
        val policy = TamperPolicy(verifier)

        val outcome = policy.enforce("kyc_submit")

        assertTrue(outcome.isFailure)
        assertEquals(cause, outcome.exceptionOrNull())
    }

    @Test fun `action label is forwarded verbatim to the verifier`() = runTest {
        val verifier = RecordingIntegrityVerifier(Result.success(true))
        val policy = TamperPolicy(verifier)

        policy.enforce("auth_change")
        policy.enforce("delete_account")
        policy.enforce("kyc_submit")

        assertEquals(
            listOf("auth_change", "delete_account", "kyc_submit"),
            verifier.calls,
        )
    }

    /**
     * Pins the safety-valve documented in [TamperPolicy]'s class comment:
     * with `EXPECTED_CERT_SHA256` blank (the default pre-Play-upload state)
     * a Tampered verdict alone must NOT block — the integrity verifier still
     * decides. Otherwise every local debug build would brick at the first
     * sensitive action.
     */
    @Test fun `Tampered signature is ignored while EXPECTED_CERT_SHA256 is blank`() = runTest {
        // Sanity-check the build-time precondition: if the test env ever
        // grows a real cert hash, this test would no longer be meaningful.
        assertEquals("", com.equipseva.app.BuildConfig.EXPECTED_CERT_SHA256)

        val verifier = RecordingIntegrityVerifier(Result.success(true))
        val policy = TamperPolicy(verifier)
        policy.setSignatureVerdict(SignatureVerifier.Verdict.Tampered)

        val outcome = policy.enforce("auth_change")

        assertTrue(outcome.isSuccess)
        // And the integrity verifier was still consulted — proving the
        // policy didn't short-circuit on the verdict.
        assertEquals(listOf("auth_change"), verifier.calls)
    }

    @Test fun `default signature verdict is Unknown and does not block`() = runTest {
        val verifier = RecordingIntegrityVerifier(Result.success(true))
        val policy = TamperPolicy(verifier)
        // No setSignatureVerdict — defaults to Unknown.

        val outcome = policy.enforce("auth_change")

        assertTrue(outcome.isSuccess)
    }

    private class RecordingIntegrityVerifier(
        private val next: Result<Boolean>,
    ) : IntegrityVerifier {
        val calls = mutableListOf<String>()

        override suspend fun requestVerification(action: String): Result<Boolean> {
            calls += action
            return next
        }
    }
}
