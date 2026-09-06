package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * round3812 — client mirrors of the round494 server constraints, locked
 * per the r1505 pattern (server CHECK mirrors are test-pinned so schema
 * drift breaks the build, not production):
 *   dsr_reports.work_summary CHECK (length BETWEEN 20 AND 5000)
 *   submit_dsr: min 20 on the TRIMMED summary
 *   hospital_sign_dsr: signer name/role length(trim(x)) >= 3
 */
class DsrValidatorsTest {

    @Test
    fun `work summary constants mirror the server CHECK bounds`() {
        assertEquals(20, DsrValidators.WORK_SUMMARY_MIN)
        assertEquals(5000, DsrValidators.WORK_SUMMARY_MAX)
    }

    @Test
    fun `summary below 20 chars is TooShort`() {
        assertEquals(DsrFieldProblem.TooShort, DsrValidators.workSummaryProblem("too short"))
        assertEquals(DsrFieldProblem.TooShort, DsrValidators.workSummaryProblem(""))
        // 19 chars exactly — one under the bound
        assertEquals(DsrFieldProblem.TooShort, DsrValidators.workSummaryProblem("a".repeat(19)))
    }

    @Test
    fun `summary at exactly 20 chars passes`() {
        assertNull(DsrValidators.workSummaryProblem("a".repeat(20)))
    }

    @Test
    fun `whitespace does not count toward the minimum — the server trims`() {
        // 19 real chars padded with spaces to 30: the RPC raises 22023 on
        // length(trim(x)) < 20, so the client must agree.
        assertEquals(
            DsrFieldProblem.TooShort,
            DsrValidators.workSummaryProblem("  " + "a".repeat(19) + "         "),
        )
        assertNull(DsrValidators.workSummaryProblem("  " + "a".repeat(20) + "  "))
    }

    @Test
    fun `summary at exactly 5000 chars passes and 5001 is TooLong`() {
        assertNull(DsrValidators.workSummaryProblem("a".repeat(5000)))
        assertEquals(DsrFieldProblem.TooLong, DsrValidators.workSummaryProblem("a".repeat(5001)))
    }

    @Test
    fun `signer fields require 3 trimmed chars, matching hospital_sign_dsr`() {
        assertFalse(DsrValidators.signerFieldOk(""))
        assertFalse(DsrValidators.signerFieldOk("ab"))
        assertFalse(DsrValidators.signerFieldOk("  ab  "))
        assertTrue(DsrValidators.signerFieldOk("abc"))
        assertTrue(DsrValidators.signerFieldOk("  Biomedical Coordinator  "))
    }

    @Test
    fun `status helpers match the round494 status literals`() {
        val pending = DsrRepository.Dsr(
            id = "x", status = DsrRepository.STATUS_PENDING_SIGN,
            engineerSignatureAt = "2026-09-06T00:00:00Z", workSummary = "s",
        )
        val signed = pending.copy(status = DsrRepository.STATUS_SIGNED)
        assertTrue(pending.isPendingSign)
        assertFalse(pending.isSigned)
        assertTrue(signed.isSigned)
        assertFalse(signed.isPendingSign)
        // the literals themselves — drift here means the app disagrees
        // with hospital_sign_dsr's state machine
        assertEquals("pending_hospital_sign", DsrRepository.STATUS_PENDING_SIGN)
        assertEquals("signed", DsrRepository.STATUS_SIGNED)
    }
}
