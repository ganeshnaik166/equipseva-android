package com.equipseva.app.features.amc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanProceedAmcWizardStepTest {

    // ---- canProceedScopeStep -----------------------------------------

    @Test fun `scope step requires at least one category`() {
        assertTrue(canProceedScopeStep(listOf("mri_scanner")))
        assertTrue(canProceedScopeStep(listOf("mri", "ct", "xray")))
    }

    @Test fun `scope step blocks empty list`() {
        assertFalse(canProceedScopeStep(emptyList()))
    }

    // ---- canProceedFrequencyFeeStep ----------------------------------

    @Test fun `frequency-fee step requires positive fee AND positive visits`() {
        assertTrue(canProceedFrequencyFeeStep("50000", visitsPerYear = 12))
        assertTrue(canProceedFrequencyFeeStep("50000.50", visitsPerYear = 4))
    }

    @Test fun `zero fee blocks (Razorpay would reject as amount_mismatch)`() {
        // Critical pin — > 0.0 strict, not >=.
        assertFalse(canProceedFrequencyFeeStep("0", 12))
        assertFalse(canProceedFrequencyFeeStep("0.0", 12))
    }

    @Test fun `negative fee blocks`() {
        assertFalse(canProceedFrequencyFeeStep("-1000", 12))
    }

    @Test fun `blank fee blocks`() {
        assertFalse(canProceedFrequencyFeeStep("", 12))
        assertFalse(canProceedFrequencyFeeStep("   ", 12))
    }

    @Test fun `non-numeric fee blocks`() {
        assertFalse(canProceedFrequencyFeeStep("not a number", 12))
        assertFalse(canProceedFrequencyFeeStep("₹500", 12))
    }

    @Test fun `zero visits blocks`() {
        assertFalse(canProceedFrequencyFeeStep("50000", 0))
    }

    @Test fun `negative visits blocks`() {
        assertFalse(canProceedFrequencyFeeStep("50000", -1))
    }

    @Test fun `whitespace-padded fee is trimmed before parse`() {
        assertTrue(canProceedFrequencyFeeStep("  50000  ", 12))
    }

    // ---- canProceedSlaStep -------------------------------------------

    @Test fun `sla step requires both std AND emerg positive`() {
        assertTrue(canProceedSlaStep("24", "4"))
    }

    @Test fun `zero std blocks`() {
        // 0-hour SLA would be meaningless.
        assertFalse(canProceedSlaStep("0", "4"))
    }

    @Test fun `zero emerg blocks`() {
        assertFalse(canProceedSlaStep("24", "0"))
    }

    @Test fun `negative std blocks (would mark every visit breached)`() {
        // Critical pin — negative hours would silently route every
        // visit as breached.
        assertFalse(canProceedSlaStep("-1", "4"))
    }

    @Test fun `negative emerg blocks`() {
        assertFalse(canProceedSlaStep("24", "-1"))
    }

    @Test fun `blank std blocks`() {
        assertFalse(canProceedSlaStep("", "4"))
    }

    @Test fun `blank emerg blocks`() {
        assertFalse(canProceedSlaStep("24", ""))
    }

    @Test fun `decimal hours allowed`() {
        // 4.5-hour SLA is valid.
        assertTrue(canProceedSlaStep("24.5", "4.5"))
    }

    // ---- canProceedEngineerStep --------------------------------------

    @Test fun `engineer step requires non-blank id`() {
        assertTrue(canProceedEngineerStep("eng-abc-123"))
    }

    @Test fun `blank engineer id blocks`() {
        assertFalse(canProceedEngineerStep(""))
        assertFalse(canProceedEngineerStep("   "))
    }
}
